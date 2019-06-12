# Taxonomic Profiles

Taxonomic profiles come from [MetaPhlAn2](https://bitbucket.org/biobakery/metaphlan2/src).
Each sample is run separately, and needs to be joined in a single table.
I'll use the function [`merge_tables`]@ref


```@example tax_profiles
cd(dirname(@__FILE__)) # hide
ENV["GKSwstype"] = "100" # hide

using ECHOAnalysis
using Pkg.TOML: parsefile
using DataFrames
using PrettyTables
using CSV
using Microbiome
using MultivariateStats
using StatsPlots
using MicrobiomePlots
using BiobakeryUtils
using ColorBrewer
using Clustering

tables = parsefile("../../data/data.toml")["tables"]
figsdir = parsefile("../../data/data.toml")["figures"]["path"]
datafolder = tables["biobakery"]["path"]
metaphlan = tables["biobakery"]["metaphlan2"]
outdir = metaphlan["analysis_output"]
isdir(outdir) || mkdir(outdir)

tax = merge_tables(datafolder, metaphlan["root"], metaphlan["filter"],
    suffix="_profile.tsv")

# clean up sample names
names!(tax,
    map(n-> Symbol(
        resolve_sampleID(String(n))[:sample]),
        names(tax)
        )
    )
pretty_table(first(tax, 10))
```

Some analysis of the fungi:

```@example tax_profiles
euk = filter(tax) do row
    occursin(r"^k__Eukaryota", row[1])
end

# remove columns that don't have any fungi
euk = euk[map(c->
    !(eltype(euk[c]) <: Number) || sum(euk[c]) > 0, names(euk))]

CSV.write(joinpath(outdir, "euk.csv"), euk)
# get a df with only species
taxfilter!(euk)
CSV.write(joinpath(outdir, "euk_sp.csv"), euk)
pretty_table(euk)
```

Those numbers are out of 100...
so really not much fungi at all,
at least according to metaplan.
There are some other methods to look more specifically at fungi,
which will have to wait for another time.

### PCoA Plots

For an initial overview,
let's look at the PCoA plots using BrayCurtis dissimilarity.

#### All Samples

```@example tax_profiles
spec = taxfilter(tax)
phyla = taxfilter(tax, :phylum)
first(spec, 10) |> pretty_table
```


```@example tax_profiles
abt = abundancetable(spec)
pabt = abundancetable(phyla)
relativeabundance!(abt)
relativeabundance!(pabt);
```

```@example tax_profiles
dm = pairwise(BrayCurtis(), occurrences(abt), dims=2)
mds = fit(MDS, dm, distances=true)

plot(mds, primary=false)
savefig(joinpath(figsdir, "05-basic_pcoa.svg")) # hide
```

![](../../data/figures/03-basic_pcoa.svg)


```@example tax_profiles
function scree(mds)
    ev = eigvals(mds)
    var_explained = [v / sum(ev) for v in ev]
    bar(var_explained, primary=false, line=0)
end

scree(mds)
ylabel!("Variance explained")
xlabel!("Principal coordinate axis")
savefig(joinpath(figsdir, "05-scree.svg")) # hide
```

![](../../data/figures/03-scree.svg)

```@example tax_profiles
color1 = ColorBrewer.palette("Set1", 9)
color2 = ColorBrewer.palette("Set2", 8)
color3 = ColorBrewer.palette("Set3", 12)
color4 = ColorBrewer.palette("Paired", 12)

c = [startswith(x, "C") ? color2[1] : color2[2] for x in samplenames(abt)]

p1 = plot(mds, marker=3, line=1, framestyle=1,
    color=c, primary=false)
scatter!([],[], color=color2[1], label="kids", legend=:topleft)
scatter!([],[], color=color2[2], label="moms", legend=:topleft)
title!("All samples taxonomic profiles")

savefig(joinpath(figsdir, "05-taxonomic-profiles-moms-kids.svg")) # hide
```

![](../../data/figures/03-taxonomic-profiles-moms-kids.svg)

```@example tax_profiles
p2 = plot(mds, marker=3, line=1,
    zcolor=shannon(abt), primary = false, color=:plasma,
    title="All samples, shannon diversity")

savefig(joinpath(figsdir, "05-taxonomic-profiles-shannon.svg")) # hide
```

![](../../data/figures/03-taxonomic-profiles-shannon.svg)

```@example tax_profiles
bacteroidetes = vec(Matrix(phyla[phyla[1] .== "Bacteroidetes", 2:end]))
firmicutes = vec(Matrix(phyla[phyla[1] .== "Firmicutes", 2:end]))

p3 = plot(mds, marker=3, line=1,
    zcolor=bacteroidetes, primary = false, color=:plasma,
    title="All samples, Bacteroidetes")

savefig(joinpath(figsdir, "05-taxonomic-profiles-bacteroidetes.svg")) # hide
```

![](../../data/figures/03-taxonomic-profiles-bacteroidetes.svg)

```@example tax_profiles
p4 = plot(mds, marker=3, line=1,
    zcolor=firmicutes, primary = false, color=:plasma,
    title="All samples, Firmicutes")

savefig(joinpath(figsdir, "05-taxonomic-profiles-firmicutes.svg")) # hide
```

![](../../data/figures/03-taxonomic-profiles-firmicutes.svg)

```@example tax_profiles
plot(p1, p2, p3, p4, marker = 2, markerstroke=0)
savefig(joinpath(figsdir, "05-taxonomic-profiles-grid.svg")) # hide
```

![](../../data/figures/03-taxonomic-profiles-grid.svg)

#### Kids

Now, I'll focus on the kids in the group,
the samples that were stored in Genotek
and also remove duplicates
(since many of the kids are sampled more than once).

```@example tax_profiles
moms = view(abt, sites=map(s-> occursin(r"^M", s[:sample]) && occursin("F", s[:sample]),
                            resolve_sampleID.(sitenames(abt))))
unique_moms = let
    subjects= []
    unique = Bool[]
    for sample in sitenames(moms)
        s = resolve_sampleID(sample)
        if !in(s[:subject], subjects)
            push!(subjects, s[:subject])
            push!(unique,true)
        else
            push!(unique,false)
        end
    end
    unique
end


umoms = view(moms, sites=unique_moms)
umoms_dm = pairwise(BrayCurtis(), umoms)
umoms_hcl = hclust(umoms_dm, linkage=:average)
optimalorder!(umoms_hcl, umoms_dm)

abundanceplot(umoms, srt=umoms_hcl.order, title="Moms, top 10 species",
    xticks=false, color=color4')
savefig(joinpath(figsdir, "05-moms-abundanceplot.svg"))
```

![](../../figures/05-moms-abundanceplot.svg)

```@example tax_profiles

kids = view(abt, sites=map(s-> occursin(r"^C", s[:sample]) && occursin("F", s[:sample]),
                    resolve_sampleID.(sitenames(abt))))
unique_kids = view(abt, sites=firstkids(resolve_sampleID.(sitenames(abt))))

kids_dm = pairwise(BrayCurtis(), kids)
kids_mds = fit(MDS, kids_dm, distances=true)

ukids_dm = pairwise(BrayCurtis(), ukids)
ukids_mds = fit(MDS, ukids_dm, distances=true)
ukids_hcl = hclust(ukids_dm, linkage=:average)
optimalorder!(ukids_hcl, ukids_dm)

abundanceplot(unique_kids, srt = ukids_hcl.order, title="Kids, top 10 species",
    xticks=false, color=color4')
savefig(joinpath(figsdir, "05-kids-abundanceplot.svg"))
```

![](../../figures/05-kids-abundanceplot.svg)


```@example tax_profiles
pcos = DataFrame(sampleID=samplenames(kids))
samples = resolve_sampleID.(samplenames(kids))
pcos[:studyID] = map(s-> s[:subject], samples)
pcos[:timepoint] = map(s-> s[:timepoint], samples)
pcos[:ginisimpson] = ginisimpson(kids)
pcos[:shannon] = shannon(kids)

proj = projection(kids_mds)


for i in 1:size(proj, 2)
    pcos[Symbol("Pco$i")] = proj[:,i]
end

CSV.write("/home/kevin/Desktop/tax_profile_pcos.csv", pcos)

p5 = plot(kids_mds, marker=3, line=1,
    zcolor=shannon(kids), primary = false, color=:plasma,
    title="Kids, shannon diversity")

savefig(joinpath(figsdir, "05-taxonomic-profiles-kids-shannon.svg")) # hide
```

![](../../data/figures/03-taxonomic-profiles-kids-shannon.svg)

```@example tax_profiles

pkids = view(pabt, sites=map(s-> occursin(r"^C", s[:sample]) && occursin("F", s[:sample]),
                            resolve_sampleID.(sitenames(pabt))))
upkids = view(pkids, sites=firstkids(resolve_sampleID.(sitenames(pkids))))

kids_bact = vec(collect(occurrences(view(pkids, species=occursin.("Bact", speciesnames(pkids))))))
kids_firm = vec(collect(occurrences(view(pkids, species=occursin.("Firm", speciesnames(pkids))))))
kids_act = vec(collect(occurrences(view(pkids, species=occursin.("Actino", speciesnames(pkids))))))
kids_proteo = vec(collect(occurrences(view(pkids, species=occursin.("Proteo", speciesnames(pkids))))))

plot(
    plot(kids_mds, marker=2, line=1,
        zcolor=kids_bact, primary = false, color=:plasma,
        title="Kids, Bacteroidetes"),
    plot(kids_mds, marker=2, line=1,
        zcolor=kids_firm, primary = false, color=:plasma,
        title="Kids, Firmicutes"),
    plot(kids_mds, marker=2, line=1,
        zcolor=kids_act, primary = false, color=:plasma,
        title="Kids, Actinobacteria"),
    plot(kids_mds, marker=2, line=1,
        zcolor=kids_proteo, primary = false, color=:plasma,
        title="Kids, Proteobacteria"),
    )
savefig(joinpath(figsdir, "05-taxonomic-profiles-kids-phyla.svg")) # hide
```

![](../../data/figures/03-taxonomic-profiles-kids-phyla.svg)

In order to decorate these PCoA plots with other useful information,
we need to return to the metadata.
I'll use the [`getmetadata`]@ref function.

#### Brain Data

```@example tax_profiles
brainvol = CSV.read("../../data/brain/brain_volumes.csv")
names!(brainvol, map(names(brainvol)) do n
                        replace(String(n), " "=>"_") |> lowercase |> Symbol
                    end
        )


brainvol = stack(brainvol, [:white_matter_volume, :grey_matter_volume, :csf_volume], :study_id, variable_name=:metadatum)
rename!(brainvol, :study_id => :studyID)

# convert letter timepoint into number
gettp(x) = findfirst(lowercase(String(x)), "abcdefghijklmnopqrstuvwxyz")[1]

brainsid = match.(r"(\d+)([a-z])", brainvol[:studyID])
brainvol[:studyID] = [parse(Int, String(m.captures[1])) for m in brainsid]
brainvol[:timepoint] = [gettp(m.captures[2]) for m in brainsid]
brainvol[:parent_table] = "brainVolume"
brainvol[:sampleID] = ""

allmeta = CSV.File("../../data/metadata/merged.csv") |> DataFrame
allmeta = vcat(allmeta, brainvol)
CSV.write("../../data/metadata/merged_brain.csv", allmeta)
```


```@example tax_profiles
samples = resolve_sampleID.(samplenames(kids))

subjects = [s.subject for s in samples]
timepoints = [s.timepoint for s in samples]
metadata = ["correctedAgeDays", "childGender", "APOE", "birthType",
            "exclusivelyNursed", "exclusiveFormulaFed", "lengthExclusivelyNursedMonths",
            "amountFormulaPerFeed", "formulaTypicalType", "milkFeedingMethods",
            "typicalNumberOfEpressedMilkFeeds", "typicalNumberOfFeedsFromBreast",
            "noLongerFeedBreastmilkAge", "ageStartSolidFoodMonths", "motherSES",
            "childHeight", "childWeight", "white_matter_volume", "grey_matter_volume", "csf_volume",
            "mullen_VerbalComposite", "VCI_Percentile", "languagePercentile"]

focusmeta = getmetadata(allmeta, subjects, timepoints, metadata)

using StatsPlots

focusmeta[:correctedAgeDays] = [ismissing(x) ? x : parse(Int, x) for x in focusmeta[:correctedAgeDays]]
scatter(focusmeta[:correctedAgeDays], proj[:,1], legend = false)
xlabel!("correctedAgeDays")
ylabel!("PCo.1")


focusmeta[:motherSES] = map(x-> ismissing(x) || x == "9999" ? missing : parse(Int, x), focusmeta[:motherSES])

focusmeta[:shannon] = shannon(kids)
focusmeta[:ginisimpson] = ginisimpson(kids)

focusmeta |> CSV.write("../../data/metadata/focus.csv") # hide

map(row-> any(!ismissing,
        [row[:mullen_VerbalComposite], row[:VCI_Percentile], row[:languagePercentile]]), eachrow(focusmeta)) |> sum
```

```@example tax_profiles
ukids_samples = resolve_sampleID.(samplenames(unique_kids))
ukids_subjects = [s.subject for s in ukids_samples]
ukids_timepoints = [s.timepoint for s in ukids_samples]
ukidsmeta = getmetadata(allmeta, ukids_subjects, ukids_timepoints, metadata)
ukidsmeta[:correctedAgeDays] = numberify(ukidsmeta[:correctedAgeDays])
youngkids = ukidsmeta[:correctedAgeDays] ./ 365 .< 2
youngkids = [ismissing(x) ? false : x for x in youngkids]

ykids = view(unique_kids, sites = youngkids)
ykids_dm = pairwise(BrayCurtis(), ykids)
ykids_mds = fit(MDS, ykids_dm, distances=true)

ykids_hcl = hclust(ykids_dm, linkage=:average)
optimalorder!(ykids_hcl, ykids_dm)
abundanceplot(ykids, srt = ykids_hcl.order, title="Kids under 2, top 10 species",
    xticks=false, color=color4')
savefig(joinpath(figsdir, "05-young-kids-abundanceplot.svg"))

```

##### Birth type

```@example tax_profiles
plot(kids_mds, marker=3, line=1,
    color=metacolor(focusmeta[:birthType], color2[4:5], missing_color=color2[end]),
    title="Kids, BirthType", primary=false)
scatter!([],[], color=color2[4], label=unique(focusmeta[:birthType])[1])
scatter!([],[], color=color2[5], label=unique(focusmeta[:birthType])[2])
scatter!([],[], color=color2[end], label="missing", legend=:bottomright)

savefig(joinpath(figsdir, "05-taxonomic-profiles-kids-birth.svg")) # hide
```

![](../../data/figures/03-taxonomic-profiles-kids-birth.svg)

##### Breastfeeding

Information about braestfeeding is spread across 2 different parent tables.
`BreastfeedingDone` indicates that the child is no longer breastfeeding,
and has a lot of information about formula use, solid food etc,
`BreastfeedingStill` is for kids that are still breastfeeding,
and has different information.

I'd like to distill all of this into:

1. breastfeeding: `true`/`false`,
2. formula: `true`/`false`

Both of these might be `true`.
In principle, they shouldn't both be `false`.

I defined [`breastfeeding`]@ref and [`formulafeeding`]@ref
to calculate these values.

```@example tax_profiles
# Make this function return `missing` instead of throwing an error
import Base.occursin
occursin(::String, ::Missing) = missing
occursin(::Regex, ::Missing) = missing

# make sure number rows are actually number types
for c in [:typicalNumberOfFeedsFromBreast, :typicalNumberOfEpressedMilkFeeds,
          :lengthExclusivelyNursedMonths, :noLongerFeedBreastmilkAge,
          :amountFormulaPerFeed]
    focusmeta[c] = [ismissing(x) ? missing : parse(Float64, x) for x in focusmeta[c]]
end


focusmeta[:breastfed] = breastfeeding.(eachrow(focusmeta))
focusmeta[:formulafed] = formulafeeding.(eachrow(focusmeta))
focusmeta |> CSV.write("../../data/metadata/metadata_with_brain.csv") # hide
```

```@example tax_profiles
bfcolor = let bf = []
    for row in eachrow(focusmeta)
        if row[:breastfed] && row[:formulafed]
            push!(bf, color1[1])
        elseif row[:breastfed]
            push!(bf, color1[2])
        elseif row[:formulafed]
            push!(bf, color1[3])
        else
            push!(bf, color1[end])
        end
    end
    bf
end

plot(kids_mds, marker=3, line=1,
    color=bfcolor,
    title="Kids, Breastfeeding", primary=false)
scatter!([],[], color=color1[2], label="breastfed")
scatter!([],[], color=color1[3], label="formula fed")
scatter!([],[], color=color1[1], label="both")
scatter!([],[], color=color1[end], label="missing", legend=:bottomright)

savefig(joinpath(figsdir, "05-taxonomic-profiles-kids-breastfeeding.svg")) # hide
```

![](../../data/figures/03-taxonomic-profiles-kids-breastfeeding.svg)

```@example tax_profiles
filter(focusmeta) do row
    !row[:breastfed] && !row[:formulafed]
end |> CSV.write("../../data/metadata/breastfeeding_missing.csv")
```

```@example tax_profiles
focusmeta[:correctedAgeDays] = [ismissing(x) ? missing : parse(Int, x) for x in focusmeta[:correctedAgeDays]]
focusmeta[:white_matter_volume] = [x for x in focusmeta[:white_matter_volume]]
focusmeta[:grey_matter_volume] = [x for x in focusmeta[:grey_matter_volume]]
focusmeta[:csf_volume] = [x for x in focusmeta[:csf_volume]]



@df focusmeta scatter(:correctedAgeDays, :white_matter_volume, label="wmv",
    xlabel="Age in Days", ylabel="Volume")
@df focusmeta scatter!(:correctedAgeDays, :grey_matter_volume, label="gmv")
@df focusmeta scatter!(:correctedAgeDays, :csf_volume, label="csf", legend=:bottomright)
title!("Brain Volumes")
ylims!(0, 3e5)
savefig(joinpath(figsdir, "05-brain-structures.svg")) # hide
```

![](../../data/figures/03-brain-structures.svg)

```@example tax_profiles
wgr = focusmeta[:white_matter_volume] ./ focusmeta[:grey_matter_volume]
@df focusmeta scatter(:correctedAgeDays, wgr, title="White/Grey Matter Ratio", primary=false,
    xlabel="Age in Days", ylabel="WMV / GMV")
savefig(joinpath(figsdir, "05-brain-wgr.svg")) # hide
```

![](../../data/figures/03-brain-wgr.svg)

```@example tax_profiles
gcr = focusmeta[:grey_matter_volume] ./ focusmeta[:csf_volume]
@df focusmeta scatter(:correctedAgeDays, gcr, title="Grey Matter/CSF Ratio", primary=false,
    xlabel="Age in Days", ylabel="GMV / CSF")
savefig(joinpath(figsdir, "05-brain-gcr.svg")) # hide
```

![](../../data/figures/03-brain-gcr.svg)

```@example tax_profiles
describe(focusmeta[:grey_matter_volume])
```

```@example tax_profiles
using StatsBase

function colorquartile(arr, clrs)
    (q1, q2, q3) = percentile(collect(skipmissing(arr)), [25, 50, 75])
    length(clrs) > 4 ? mis = colorant"gray" : clrs[5]
    map(arr) do x
        ismissing(x) && return mis
        x < q1 && return clrs[1]
        x < q2 && return clrs[2]
        x < q3 && return clrs[3]
        return clrs[4]
    end
end

colorquartile(focusmeta[:grey_matter_volume], color2[[1,2,3,4,end]])


scatter(projection(kids_mds)[:,1], focusmeta[:correctedAgeDays] ./ 365,
    color=colorquartile(focusmeta[:grey_matter_volume], color2[[1,2,3,4,end]]),
    legend=:topleft, primary=false)
scatter!([], [], color=color2[1], label="25th percentile")
scatter!([], [], color=color2[2], label="50th percentile")
scatter!([], [], color=color2[3], label="75th percentile")
scatter!([], [], color=color2[4], label="100th percentile")
scatter!([], [], color=color2[end], label="missing")
```