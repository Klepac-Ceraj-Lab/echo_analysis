module ECHOAnalysis

export
    ## Samples, Timepoints, and Metdata
    AbstractTimepoint,
    sampleid,
    subject,
    timepoint,
    Timepoint,
    StoolSample,
    stoolsample,
    iskid,
    ismom,
    sampletype,
    resolve_letter_timepoint,
    uniquetimepoints,
    uniquesubjects,
    breastfeeding,
    samplelessthan,
    numberify,
    widemetadata,

    ## Database Operations
    sampletable,
    getlongmetadata

using SQLite
using DataFrames
using CSV
using Colors
using Microbiome
using BiobakeryUtils

include("samples.jl")
include("metadata_handling.jl")
include("sqlops.jl")

end  # module ECHOAnalysis
