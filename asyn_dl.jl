"""
	extension 会添加在GRB_name之后 e.g. ".html"
"""
function channel_download(
    c::Channel{String}, GRB_years::Vector, GRB_names::Vector;
    directory="temp", extension=""
)
    @sync for (year, name) in zip(GRB_years, GRB_names)
        file_path = directory * "/$year/$name" * extension
        mkpath(directory * "/$year")  ### request output 目录必须已经存在， 否则异步会卡住
        if !isfile(file_path)
            @spawn try
                push!(c, name)
                request(Trigger_Site * "$year/$name/current";
                    output=file_path)  ### using Downloads 
                take!(c)
            catch e
                @info e
                take!(c)
                isfile(file_path) && rm(file_path)
            end
        end
    end
end


"""
	download single files   
"""
function channel_download(
    c::Channel{String},
    GRB_years::Vector,
    GRB_names::Vector,
    GRB_file_names::Vector{String};
    directory="temp"
)
    @sync for (year, name, file) in zip(GRB_years, GRB_names, GRB_file_names)
        mkpath(directory * "/$year/$name")
        file_path = directory * "/$year/$name/$file"
        if !isfile(file_path)
            @spawn try
                push!(c, name)
                request(Trigger_Site * "$year/$name/current/$file";
                    output=file_path)
                take!(c)
            catch e
                @info e
                take!(c)
                isfile(file_path) && rm(file_path)
            end
        end
    end
end


"""
	download multiple files 
"""
function channel_download(
    c::Channel{String},
    GRB_years::Vector,
    GRB_names::Vector,
    GRB_file_names::Vector{Vector{String}};
    directory="temp"
)
    @sync for (year, name, files) in zip(GRB_years, GRB_names, GRB_file_names)
        mkpath(directory * "/$year/$name")
        for file in files
            file_path = directory * "/$year/$name/$file"
            if !isfile(file_path)
                @spawn try
                    push!(c, name)
                    request(Trigger_Site * "$year/$name/current/$file";
                        output=file_path)
                    take!(c)
                catch e
                    @info e
                    take!(c)
                    isfile(file_path) && rm(file_path)
                end
            end
        end
    end
end
