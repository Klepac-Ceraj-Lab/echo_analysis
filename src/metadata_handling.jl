"""
    safeoccursin(s::String, thing)
    safeoccursin(r::Regex, thing)

Same as `Base.occursin`, except returns `missing`
if the thing to be searched is `missing`
rather than throwing an error.
"""
safeoccursin(s::String, thing::Any) = occursin(s, thing)
safeoccursin(r::Regex, thing::Any) = occursin(r, thing)
safeoccursin(::String, ::Missing) = missing
safeoccursin(::Regex, ::Missing) = missing

"""
    safematch(s::String, thing)
    safematch(r::Regex, thing)

Same as `Base.match`, except returns `nothing`
if the thing to be searched is `missing`
rather than throwing an error.
"""
safematch(s::String, thing::Any) = match(s, thing)
safematch(r::Regex, thing::Any) = match(r, thing)
safematch(::String, ::Missing) = nothing
safematch(::Regex, ::Missing) = nothing

"""
    breastfeeding(row::DataFrameRow)

Checks a wide-form metadata row for breastfeeding information.
Possible return values are

- `:breastfed`: at least 3 months exlussively breastfed,
    or where at least 80% of feedings are from breast
- `:formulafed`: no breastmilk after 2 weeks
- `:mixed`: all others
- `missing`: not enough information
"""
function breastfeeding(row::DataFrameRow)
    # not yet working
    bf = any([
        safeoccursin(r"[Bb]reast", row[:milkFeedingMethods]),
        safeoccursin(r"[Yy]es", row[:exclusivelyNursed]),
        all(map(x->safeoccursin(r"[Nn]o", x), row[[:exclusiveFormulaFed, :exclusivelyNursed]])),
        row[:typicalNumberOfFeedsFromBreast] > 0,
        row[:typicalNumberOfEpressedMilkFeeds] > 0,
        row[:lengthExclusivelyNursedMonths] > 0,
        row[:noLongerFeedBreastmilkAge] > 0
        ])
    # return !ismissing(bf) && bf
    return missing
end

"""
    numberify(x)
    numberify(v::AbstractArray)

Try to convert something into a number or array of numbers using the heuristics:
- if x is already a number or is `missing`, return x
- if v is already an array of numbers, return v
- if x is a `String`:
    - if x contains a `.` or `e`, parse as a `Float64`
    - Otherwise parse as an Int
- if numberified vector contains any `Float`s, return a vector of `missing` and `Float64`
- if x is anything other than a String or a number, return `missing`
"""
function numberify(x)
    ismissing(x) && return missing
    x isa Real && return x
    if x isa AbstractString
        safeoccursin(r"[\.e]", x) ? parse(Float64, x) : parse(Int, x)
    else
        @warn "Something weird" x typeof(x)
        return missing
    end
end

function numberify(v::AbstractArray)
    eltype(v) <: Union{Missing, <:Real} && return v
    v = numberify.(v)
    if any(i -> i isa Float64, v)
        return Union{Missing, Float64}[y for y in v]
    else
        return Union{Missing, Int}[y for y in v]
    end
end

"""
    metacolor(metadata::AbstractVector, colorlevels::AbstractVector; missing_color=colorant"gray")

Convert metadata into colors
"""
function metacolor(metadata::AbstractVector, colorlevels::AbstractVector; missing_color=colorant"gray")
    um = unique(skipmissing(metadata))
    length(um) <= length(colorlevels) || throw(ErrorException("Not enough colors"))

    color_dict = Dict(um[i] => colorlevels[i] for i in eachindex(um))
    return [ismissing(m) ? missing_color : color_dict[m] for m in metadata]
end

"""
Get the metadata value for a given subject and timepoint
"""
function getmetadatum(df, metadatum, subject, timepoint=0; default=missing, type=nothing)
    m = filter(df) do row
        !any(ismissing, [row[:metadatum], row[:subject], row[:timepoint]]) &&
            row[:metadatum] == metadatum &&
            row[:subject] == subject &&
            row[:timepoint] == timepoint
    end

    nrow(m) == 0 && return default
    nrow(m) > 1 && throw(ErrorException("More than one value found"))

    v = first(m[!,:value])
    if type === nothing
        return v
    elseif ismissing(v)
        return default
    elseif type <: Number
        return parse(type, v)
    else
        return v
    end
end


const metadata_focus_headers = String[
    # fecal sample info
    "Mgx_batch",
    "DOM",
    "RAInitials_Extract",
    # basic data
    "childGender",
    "milkFeedingMethods",
    "APOE",
    "birthType",
    "exclusivelyNursed",
    "exclusiveFormulaFed",
    "formulaTypicalType",
    "breastFedPercent",
    "mother_HHS",
    "motherHHS_Occu",
    "motherHHS_Edu",
    "assessmentDate",
    # calculated
    "ageLabel",
    "cogAssessment",
    "cogScore",
    # numeric
    "correctedAgeDays",
    "amountFormulaPerFeed",
    "lengthExclusivelyNursedMonths",
    "typicalNumberOfEpressedMilkFeeds",
    "typicalNumberOfFeedsFromBreast",
    "noLongerFeedBreastmilkAge",
    "ageStartSolidFoodMonths",
    "childHeight",
    "childWeight",
    ## From brain data
    "subcortical",
    "neocortical",
    "cerebellar",
    "limbic",
    "hires_total",
    "white_matter_volume",
    "grey_matter_volume",
    "csf_volume",
    ## Cognitive assessments
    ### Mullen (0-3 years 11 months)
    "mullen_VerbalComposite",
    "mullen_NonVerbalComposite",
    "mullen_EarlyLearningComposite", # average of other two
    ### Bayley's (1-25 months)
    "adaptiveBehaviorComposite",
    "languageComposite",
    "socialEmotionalComposite",
    "motorComposite",
    ### WISC (6-16 years)
    "FRI_CompositeScore",
    "PSI_Composite",
    "VCI_CompositeScore",
    "VSI_CompositeScore",
    "WMI_Composite",
    "FSIQ_Composite", # average
    ### WPPSI-IV (4-5 years 11 months)
    "fluidReasoningComposite",
    "verbalComprehensionComposite",
    "visualSpatialComposite",
    "workingMemoryComposite",
    "fullScaleComposite", # average
    ]

# Use value types for special cases. See
#   https://docs.julialang.org/en/v1/manual/types/#%22Value-types%22-1
#   https://discourse.julialang.org/t/special-case-handling-alternatives-to-if-else/21608/4
struct MDColumn{T}
end

MDColumn(s::String) = MDColumn{Symbol(s)}()
MDColumn(s::Symbol) = MDColumn{s}()

customprocess(col, ::MDColumn) = col

# Make numeric
customprocess(col, ::MDColumn{:correctedAgeDays})                   = numberify(col)
customprocess(col, ::MDColumn{:amountFormulaPerFeed})               = numberify(col)
customprocess(col, ::MDColumn{:lengthExclusivelyNursedMonths})      = numberify(col)
customprocess(col, ::MDColumn{:typicalNumberOfEpressedMilkFeeds})   = numberify(col)
customprocess(col, ::MDColumn{:typicalNumberOfFeedsFromBreast})     = numberify(col)
customprocess(col, ::MDColumn{:noLongerFeedBreastmilkAge})          = numberify(col)
customprocess(col, ::MDColumn{:ageStartSolidFoodMonths})            = numberify(col)
customprocess(col, ::MDColumn{:breastFedPercent})                   = numberify(col)
customprocess(col, ::MDColumn{:childHeight})                        = numberify(col)
function customprocess(col, ::MDColumn{:Mgx_batch})
    ms = (safematch.(r"[Bb]atch (\d+)", b) for b in col)
    return [isnothing(m) ? missing : parse(Int, m.captures[1]) for m in ms]
end


## brain volumes
customprocess(col, ::MDColumn{:cerebellar})                         = numberify(col)
customprocess(col, ::MDColumn{:subcortical})                        = numberify(col)
customprocess(col, ::MDColumn{:neocortical})                        = numberify(col)
customprocess(col, ::MDColumn{:limbic})                             = numberify(col)
customprocess(col, ::MDColumn{:hires_total})                        = numberify(col)
customprocess(col, ::MDColumn{:white_matter_volume})                = numberify(col)
customprocess(col, ::MDColumn{:grey_matter_volume})                 = numberify(col)
customprocess(col, ::MDColumn{:csf_volume})                         = numberify(col)


## Cog scores
customprocess(col, ::MDColumn{:cogScore})                           = numberify(col)
### Mullen
customprocess(col, ::MDColumn{:mullen_VerbalComposite})             = numberify(col)
customprocess(col, ::MDColumn{:mullen_NonVerbalComposite})          = numberify(col)
customprocess(col, ::MDColumn{:mullen_EarlyLearningComposite})      = numberify(col)
### WSSPI-IV
customprocess(col, ::MDColumn{:fluidReasoningComposite})            = numberify(col)
customprocess(col, ::MDColumn{:fullScaleComposite})                 = numberify(col)
customprocess(col, ::MDColumn{:verbalComprehensionComposite})       = numberify(col)
customprocess(col, ::MDColumn{:visualSpatialComposite})             = numberify(col)
customprocess(col, ::MDColumn{:workingMemoryComposite})             = numberify(col)
### WISC-V
customprocess(col, ::MDColumn{:FRI_CompositeScore})                 = numberify(col)
customprocess(col, ::MDColumn{:FSIQ_Composite})                     = numberify(col)
customprocess(col, ::MDColumn{:PSI_Composite})                      = numberify(col)
customprocess(col, ::MDColumn{:VCI_CompositeScore})                 = numberify(col)
customprocess(col, ::MDColumn{:VSI_CompositeScore})                 = numberify(col)
customprocess(col, ::MDColumn{:WMI_Composite})                      = numberify(col)
### Bayley's
customprocess(col, ::MDColumn{:adaptiveBehaviorComposite})          = numberify(col)
customprocess(col, ::MDColumn{:languageComposite})                  = numberify(col)
customprocess(col, ::MDColumn{:socialEmotionalComposite})           = numberify(col)
customprocess(col, ::MDColumn{:motorComposite})                     = numberify(col)

# other custom processing
function customprocess(col, ::MDColumn{:mother_HHS})
    col = numberify(col)
    # some missing entries are encoded as 9999
    for i in eachindex(col)
        if !ismissing(col[i]) && col[i] >= 9999
            col[i] = missing
        end
    end
    return col
end

function customprocess(col, ::Union{MDColumn{:motherHHS_Occu},MDColumn{:motherHHS_Edu}})
    return customprocess(col, MDColumn(:mother_HHS))
end

"""
    widemetadata(longdf::AbstractDataFrame, samples::Vector{<:StoolSample};
                        metadata::Set=Set(unique(longdf.metadatum)),
                        parents::Set=Set(unique(longdf.parent_table)))
    widemetadata(longdf::AbstractDataFrame, samples::Vector{<:AbstractString}; kwargs...)
    widemetadata(db::SQLite.DB, tablename, samples; kwargs...)

Convert data in a long-form metadata table into wide-form,
where each sample is given a single row
and each metadatum a single column.

Timepoint-specific metadata
(specifically, metadata that comes from a parent table that has a `timepoint` field)
is only associated with samples from that timepoint,
while others (eg. childGender)
are associated with every sample for a given subject.

Optional:
    - Pass vector of Parent Tables to include
    - Pass vector of metadatum fields to include
"""
function widemetadata(longdf::AbstractDataFrame, samples::Vector{<:StoolSample};
                        metadata::Set=Set(unique(longdf.metadatum)),
                        parents::Set=Set(unique(longdf.parent_table)))
    filter!(row-> row.parent_table in parents, longdf)
    df = DataFrame((sample=sampleid(s), subject=subject(s), timepoint=timepoint(s)) for s in samples)

    ss = unique(df.subject)
    subtps = Dict(s => Set([0, df.timepoint[findall(isequal(s), df.subject)]...]) for s in ss)

    submap = Dict(s => findall(isequal(s), df.subject) for s in ss)
    tpmap = Dict(t => findall(isequal(t), df.timepoint) for t in unique(df.timepoint))

    metadict = Dict{Int,Dict}()
    notime_metadata = Set()
    timepoint_metadata = Set()

    nsamples = nrow(df)
    metadata = intersect(metadata, longdf.metadatum)
    for md in metadata
        v = view(longdf, longdf.metadatum .== md, :)
        if length(unique(v.parent_table)) != 1
            v.metadatum .= map(row-> join([row.metadatum, row.parent_table], "___"), eachrow(v))

            # add new metadatum names and remove old one
            metadata = union(metadata, v.metadatum)
            pop!(metadata, md)
        end


        for ms in Symbol.(unique(v.metadatum))
            df[!,ms] = Array{Any}(missing, nsamples)
        end
    end

    for row in eachrow(longdf)
        sub = row[:subject]
        tp = row[:timepoint]
        md = String(row[:metadatum])
        val = row[:value]
        if !any(ismissing, [sub, tp, md]) && md in metadata && sub in df.subject && tp in subtps[sub]
            if tp == 0
                rows = submap[sub]
            else
                rows = collect(intersect(submap[sub], tpmap[tp]))
            end
            df[rows, Symbol(md)] .= val
        end
    end
    for n in names(df)
        df[!,n] = customprocess(df[!,n], MDColumn(n))
    end
    return df
end

function widemetadata(db::SQLite.DB, tablename, samples; kwargs...)
    df = SQLite.Query(db, "SELECT * FROM $tablename") |> DataFrame
    widemetadata(df, samples; kwargs...)
end

widemetadata(longdf::AbstractDataFrame, samples::Vector{<:AbstractString}; kwargs...) = widemetadata(longdf, stoolsample.(samples); kwargs...)


"""
    uniquetimepoints(samples::AbstractVector{<:AbstractTimepoint};
                        samplefilter=x->true,
                        sortfirst=true,
                        takefirst=true)
    uniquetimepoints(samples::AbstractVector{<:StoolSample};
                        skipethanol=true,
                        samplefilter=x->true,
                        sortfirst=true,
                        takefirst=true)

Identifies unique timepoints (that is, `subject=>timepoint` pairs)
from a vector of [`AbstractTimepoint`]@ref.

**Example:**

Given the following array of 4 samples:

```@example uniquetimepoints
s = stoolsample(["C0001_1F_1A", "C0001_1F_2A", "C0001_2F_1A", "C0002_1F_1A"])
```

The second item will be excluded, since it's a duplicate of the first.
If a single sample for each subject is desired, use [`uniquesubjects`]@ref

**Other parameters**

- `skipethanol=true`: exlude samples that match the pattern `_\\dE_`,
    that is ethanol (as opposed to genotek) samples.
- `samplefilter=x->true`: a function to select samples to include.
  By default, all samples are included. Use `samplefilter=iskid`
  to include only child samples for example.
- `sortfirst=true`: if `true`, sorts the vector at the beginning
- `takefirst=false`: if `true`, only takes 1 timepoint for each subject.
    Use with `sortfirst` to get only the first timepoint.
"""
function uniquetimepoints(samples::AbstractVector{<:StoolSample};
                           skipethanol=true, samplefilter=x->true,
                           sortfirst=true, takefirst=false)
    seen = Tuple[]
    uniquesamples = StoolSample[]
    sortfirst && (samples = sort(samples))

    map(samples) do s
        !samplefilter(s) && return nothing
        skipethanol && sampletype(s) == "ethanol" && return nothing

        takefirst ? subtp = (subject(s),) : subtp = (subject(s), timepoint(s))
        if !in(subtp, seen)
            push!(seen, subtp)
            push!(uniquesamples, s)
        end
    end
    return uniquesamples
end

function uniquetimepoints(samples::AbstractVector{<:AbstractString}; kwargs...)
    ss = stoolsample.(samples)
    return uniquetimepoints(ss; kwargs...)
end

"""
    uniquesubjects(samples::AbstractVector{<:AbstractTimepoint};
                                samplefilter=x->true, sortfirst=true)
    uniquesubjects(samples::AbstractVector{<:StoolSample};
                        skipethanol=true, samplefilter=x->true, sortfirst=true)

Returns a single sample per subject
from a vector of [`AbstractTimepoint`]@ref.

**Example:**

Given the following array of 4 samples:

```@example uniquesubjects
s = stoolsample(["C0001_1F_1A", "C0001_1F_2A", "C0001_2F_1A", "C0002_1F_1A"])
```

The second and third samples will be excluded,
since they are both from the same subject as the first sample.
If a single sample for each subject/timepoint pair is desired, use [`uniquetimepoints`]@ref

**Other parameters**

- `skipethanol=true`: exlude samples that match the pattern `_\\dE_`,
    that is ethanol (as opposed to genotek) samples.
- `samplefilter=x->true`: a function to select samples to include.
  By default, all samples are included. Use `samplefilter=iskid`
  to include only child samples for example.
- `sortfirst=true`: if `true`, sorts the vector (to pick the earliest timepoint
  of each subject)
"""
function uniquesubjects(samples::AbstractVector{<:StoolSample};
                           skipethanol=true, samplefilter=x->true, sortfirst=true)
    seen = Int[]
    uniquesamples = StoolSample[]
    sortfirst && (samples = sort(samples))

    map(samples) do s
        !samplefilter(s) && return nothing
        skipethanol && sampletype(s) == "ethanol" && return nothing

        sub = subject(s)
        if !in(sub, seen)
            push!(seen, sub)
            push!(uniquesamples, s)
        end
    end
    return uniquesamples
end

function uniquesubjects(samples::AbstractVector{<:AbstractString}; kwargs...)
    ss = stoolsample.(samples)
    return uniquesubjects(ss; kwargs...)
end
