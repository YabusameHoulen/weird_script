### 得到选择的文件
##可以测试 得到有两种 记录方式
# if message!="Triggered detectors: (0-13)" && message!="Triggered detectors: (0-11)"
#     println(message)
# end

const Trigger_Site = "https://heasarc.gsfc.nasa.gov/FTP/fermi/data/gbm/triggers/"
using .Threads
include("Asyn_dl.jl")


"得到 GRB的 html 数据， 保存到本地， 用于提取出下载文件和版本信息"
function get_GRB_html(dl_targets::DataFrame;
    save_path="testt_html_download")
    _get_GRB_html(dl_targets.year, dl_targets.target_name; save_path)
end
function _get_GRB_html(GRB_years, GRB_names; save_path)
    dir = mkpath(save_path)
    println("start looking")
    ### 下载设置
    dl_state = Channel{String}(600) # 限制最大下载数目，防止 Open too many files error
    ### 下载 html
    channel_download(dl_state, GRB_years, GRB_names; directory=dir, extension=".html")
    println("temp html files downloaded")
end


"从网页中提取数据, 塞进下载目标DataFrame"
function get_GRB_filename!(dl_targets::DataFrame; html_path="temp_html_download")
    _get_GRB_filename!(dl_targets, dl_targets.year, dl_targets.target_name; html_path)
end
function _get_GRB_filename!(dl_targets, GRB_years, GRB_names; html_path)
    println("start add file names")
    num = size(GRB_names, 1)
    ### 注意rsp2要在rsp前，否则只能查询到.rsp文件......
    trigdets_str = r"glg_trigdat_all_bn[0-9]{9}_v0[0-9].fit"
    ttes_str = r"glg_tte_[b,n][0-9,a,b]_bn[0-9]{9}_v0[0-9].fit"
    cspecs_str = r"glg_cspec_[b,n][0-9,a,b]_bn[0-9]{9}_v0[0-9].pha"
    rsps_str = r"glg_cspec_[b,n][0-9,a,b]_bn[0-9]{9}_v0[0-9].(rsp2|rsp)"

    trig_dets = Vector{String}(undef, num)
    ttes_files = Vector{Vector{String}}(undef, num)
    cspecs_files = Vector{Vector{String}}(undef, num)
    rsps_files = Vector{Vector{String}}(undef, num)

    ###### 处理html, 正则表达式查找
    for i in 1:num
        try
            html_str = read("$html_path/$(GRB_years[i])/$(GRB_names[i]).html") |> String
            trig_det = match(trigdets_str, html_str)
            tte_file = eachmatch(ttes_str, html_str) |> collect
            cspecs_file = eachmatch(cspecs_str, html_str) |> collect
            rsps_file = eachmatch(rsps_str, html_str) |> collect

            ### 得到字符串
            trig_dets[i] = trig_det.match
            ttes_files[i] = getproperty.(tte_file, :match) |> unique!
            cspecs_files[i] = getproperty.(cspecs_file, :match) |> unique!
            rsps_files[i] = getproperty.(rsps_file, :match) |> unique!
        catch
            show("extract targets in $html_path/
             $(GRB_years[i])/$(GRB_names[i]).html incorrectly")
            break
        end
    end
    dl_targets.trig_dets = trig_dets
    dl_targets.ttes_files = ttes_files
    dl_targets.cspecs_files = cspecs_files
    dl_targets.rsps_files = rsps_files

    println("file names has been added")
    nothing
end


"下载 TRIG 来筛选 TTE/Cspec/RSP 文件"
function trig_dets_file!(dl_targets::DataFrame;
    dl_trig=true, dl_path="dets_download", modify=false)
    _trig_dets_file!(dl_targets, dl_targets.year,
        dl_targets.target_name,
        dl_targets.trig_dets,
        dl_targets.ttes_files,
        dl_targets.cspecs_files,
        dl_targets.rsps_files;
        dl_trig, dl_path, modify)
end
function _trig_dets_file!(dl_targets, GRB_years,
    GRB_names, GRB_trig, GRB_tte, GRB_cspec, GRB_rsp;
    dl_trig, dl_path, modify)::Nothing
    dir = mkpath(dl_path)
    ### 下载设置
    dl_state = Channel{String}(100) # 限制最大下载数目，防止 Open too many files error
    ### 下载 glg_trigdat_all
    if dl_trig
        println("start downloading")
        channel_download(dl_state, GRB_years, GRB_names, GRB_trig; directory=dir)
        println("download trig data finish")
    end

    modify && modifying_dets!(dl_targets, GRB_years, GRB_names,
        GRB_trig, GRB_tte, GRB_cspec, GRB_rsp)

    nothing
end


"下载探头数据,在网络好的地方应该完全没有问题"
function download_det_file(dl_targets::DataFrame;
    dl_path="dets_download", dl_tte=false, dl_cspec=false, dl_rsp=false)
    _download_det_file(
        dl_targets.year,
        dl_targets.target_name,
        dl_targets.ttes_files,
        dl_targets.cspecs_files,
        dl_targets.rsps_files;
        dl_path, dl_tte, dl_cspec, dl_rsp
    )
end
function _download_det_file(GRB_years, GRB_names, GRB_tte, GRB_cspec, GRB_rsp;
    dl_path, dl_tte, dl_cspec, dl_rsp)::Nothing

    dl_state = Channel{String}(200) # 限制最大下载数目，防止 Open too many files error
    dir = mkpath(dl_path)
    if dl_cspec
        println("downloading cspec !!!!!!!!!!")
        channel_download(dl_state, GRB_years, GRB_names, GRB_cspec; directory=dir)
        println("download cspec finish")
    end

    if dl_rsp
        println("downloading rsp & rsp2 !!!!!!!!!!")
        channel_download(dl_state, GRB_years, GRB_names, GRB_rsp; directory=dir)
        println("download rsp&rsp2 finish")
    end

    if dl_tte
        println("downloading tte !!!!!!!!!!")
        channel_download(dl_state, GRB_years, GRB_names, GRB_tte; directory=dir)
        println("download tte finish")
    end

    return nothing
end


"下载GRB预览图片(可选)"
function get_GRB_picture(dl_targets::DataFrame; dl_path="temp_picture_download")
    _get_GRB_picture(dl_targets.year, dl_targets.target_name; dl_path)
end
function _get_GRB_picture(GRB_years, GRB_names; dl_path)
    dir = mkpath(dl_path)
    for i in unique(GRB_years)
        mkpath(dir * "/$i")
    end
    println("start download")

    ### 下载设置
    dl_state = Channel{String}(1000) ### 登记后下载，限制最大下载数目，防止 Open too many files error

    ### 下载
    @sync for (year, name) in zip(GRB_years, GRB_names)
        mkpath(dir * "/$year")
        @spawn begin
            push!(dl_state, name)
            request(Trigger_Site * "$year/$name/quicklook/glg_lc_all_$(name).gif";
                output=dir * "/$year/$(name).gif")
            take!(dl_state)
        end
    end
    println("download temp GRB picture")
end


"对下载好的数据进行测试"
function test_dldata(GBM_target::DataFrame; data_path="dets_download")
    error_channel = Channel{String}(Inf)
    @sync for grb in eachrow(GBM_target)
        GBM_dir = "$data_path/$(grb.year)/$(grb.target_name)/"
        target_files = readdir(GBM_dir)[2:end]

        Threads.@spawn for t in target_files
            try
                det_files = FITS(GBM_dir * t)
                DataFrame(det_files[3])  ### 主要在检查tte的光子到达时间
                close(det_files)
            catch e
                put!(error_channel, "$(grb.year),$(grb.target_name),下载有误,$e")
                continue
            end
        end

        println(grb.target_name, " has been examined")
    end
    return error_channel
end


"返回一个下载目标Dataframe,打不开的文件可以再次下载"
function redl_target(c::Channel; txt_record="Error_Dl.txt")::DataFrame
    errored_grb = open(txt_record, "w")
    write(errored_grb, "year,target_name,下载有误,error\n")
    if !isempty(c)
        for i in c
            isempty(c) && break
            write(errored_grb, i, '\n')
        end
    end
    close(errored_grb)
    re_target = CSV.read(txt_record, DataFrame; select=[:year, :target_name])
    return unique!(re_target)
end


"根据trig_all 文件 的det_mask选择探头"
function dets_chosen(det_mask::String)
    chosen_dets = String[]
    for (id, label) in enumerate(det_mask)
        if label == '1'
            det = id < 11 ? "_n$(id-1)_" :
                  id == 11 ? "_na_" :
                  id == 12 ? "_nb_" :
                  id == 13 ? "_b0_" :
                  id == 14 ? "_b1_" :
                  throw(DomainError("这里有个奇怪的 $det_mask"))
            push!(chosen_dets, det)
        end
    end
    return chosen_dets
end

"三层for循环O(n^3)遍历挑选..."
function chooose!(
    chosen_files::Vector{Vector{String}},
    id_range::UnitRange,
    dets::Vector{String},
    GRB_files::Vector{Vector{String}},
)
    for (id, file_dets, files) in zip(id_range, dets, GRB_files)
        chosen_file = String[]
        for file_det in file_dets
            for file in files
                occursin(file_det, file) && push!(chosen_file, file)
            end
        end
        chosen_files[id] = chosen_file
    end
end


"根据trig_all对GRB进行筛选 暂时用不到"
function modifying_dets!(dl_targets, GRB_years, GRB_names, GRB_trig,
    GRB_tte, GRB_cspec, GRB_rsp)
    println("start modify")
    num = size(GRB_years, 1)
    dets = Vector{Vector{String}}(undef, num)
    ### 从 TRIG 中挑选探头
    for (i, year, name, trig_name) in zip(1:num, GRB_years, GRB_names, GRB_trig)
        (tte_mask, message) = try ### FITSIO打不开也时有发生...
            tte_file = FITS(dir * "/$year/$name/$trig_name")
            det_mask = read_key(tte_file[1], "DET_MASK")
            close(tte_file)
			# e.g. "00000000011000","Triggered detectors: (0-13)"
            first(det_mask), last(det_mask)  
        catch
            open("wrong_dl.txt", "a+") do io
                println(io, "$year $name $trig_name can't open")
            end
            continue
        end

        chosen_dets = dets_chosen(tte_mask)
        message == "Triggered detectors: (0-11)" && append!(chosen_dets, ["_b0_", "_b1_"])
        dets[i] = chosen_dets
    end

    println("modify download_targets")
    dl_targets.dets = dets
    chosen_ttes = Vector{Vector{String}}(undef, num)
    chosen_cspecs = Vector{Vector{String}}(undef, num)
    chosen_rsps = Vector{Vector{String}}(undef, num)

    ### 三层for循环O(n^3)遍历挑选...
    chooose!(chosen_ttes, 1:num, dets, GRB_tte)
    chooose!(chosen_cspecs, 1:num, dets, GRB_cspec)
    chooose!(chosen_rsps, 1:num, dets, GRB_rsp)

    ### 挑选探头放进DataFrame
    dl_targets.ttes_files = chosen_ttes
    dl_targets.cspecs_files = chosen_cspecs
    dl_targets.rsps_files = chosen_rsps

    nothing
end
