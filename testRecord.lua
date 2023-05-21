--- 模块功能：录音功能测试.
-- @author openLuat
-- @module record.testRecord
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"record"
require"audio"
require"http"

--每次读取的录音文件长度
local RCD_READ_UNIT = 1024
--rcdoffset：当前读取的录音文件内容起始位置
--rcdsize：录音文件总长度
--rcdcnt：当前需要读取多少次录音文件，才能全部读取
local rcdoffset,rcdsize,rcdcnt
--设置为spk播放，耳机mic输入
--audio.setChannel(2, 3)
--设置录音时mic增益为7级
--audio.setMicGain("record",7)
--[[
函数名：playcb
功能  ：播放录音结束后的回调函数
参数  ：无
返回值：无
]]
local function playcb(r)
    log.info("testRecord.playcb",r)
    --删除录音文件
    record.delete()
    record.start(5,rcdcb)
    sys.timerStart(record.stop,3000)
end

local function cbFnc(result,prompt,head,body)
    log.info("testRecord uploads file, cbFnc",result,prompt)
    if result and head then
        for k,v in pairs(head) do
            log.info("testRecord uploads file, cbFnc",k..": "..v)
        end
    end
    if result and body then
        log.info("testRecord uploads file, cbFnc","bodyLen="..body:len())
        log.info(body)
    end
end
--如下示例代码是利用multipart/form-data模式，上传2参数和1个照片文件

local function postMultipartFormData(url,cert,params,timeout,cbFnc,rcvFileName)
    local boundary,body,k,v,kk,vv = "--------------------------"..os.time()..rtos.tick(),{}
    
    for k,v in pairs(params) do
        if k=="texts" then
            local bodyText = ""
            for kk,vv in pairs(v) do
                bodyText = bodyText.."--"..boundary.."\r\nContent-Disposition: form-data; name=\""..kk.."\"\r\n\r\n"..vv.."\r\n"
            end
            body[#body+1] = bodyText
        elseif k=="files" then
            local contentType =
            {
                jpg = "image/jpeg",
                jpeg = "image/jpeg",
                png = "image/png",
                amr = "audio/amr",
            }
            for kk,vv in pairs(v) do
                print(kk,vv)
                body[#body+1] = "--"..boundary.."\r\nContent-Disposition: form-data; name=\""..kk.."\"; filename=\""..kk.."\"\r\nContent-Type: "..contentType[vv:match("%.(%w+)$")].."\r\n\r\n"
                body[#body+1] = {file = vv}
                body[#body+1] = "\r\n"
            end
        end
    end    
    body[#body+1] = "--"..boundary.."--\r\n"
        
    http.request(
        "POST",
        url,
        cert,
        {
            ["Content-Type"] = "multipart/form-data; boundary="..boundary,
            ["Connection"] = "keep-alive"
        },
        body,
        timeout,
        cbFnc,
        rcvFileName
        )    
end


--[[
函数名：readrcd
功能  ：读取录音文件内容
参数  ：无
返回值：无
]]
local function readrcd()    
    local s = record.getData(rcdoffset,RCD_READ_UNIT)
    log.info("testRecord.readrcd",rcdoffset,rcdcnt,string.len(s))
    rcdcnt = rcdcnt-1
    --录音文件内容已经全部读取出来
    if rcdcnt<=0 then
        sys.timerStop(readrcd)
        --播放录音内容
        --audio.play(0,"FILE",record.getFilePath(),7,playcb)
        postMultipartFormData(
            "http://1.n.rho.im:8085/upload",
            nil,
            {
                files =
                {
                    ["file.amr"] = record.getFilePath()
                }
            },
            60000,
            cbFnc
        )

    --还没有全部读取出来
    else
        rcdoffset = rcdoffset+RCD_READ_UNIT
    end
end

--[[
函数名：rcdcb
功能  ：录音结束后的回调函数
参数  ：
        result：录音结果，true表示成功，false或者nil表示失败
        size：number类型，录音文件的大小，单位是字节，在result为true时才有意义
返回值：无
]]
function rcdcb(result,size)
    log.info("testRecord.rcdcb",result,size)
    if result then
        rcdoffset,rcdsize,rcdcnt = 0,size,(size-1)/RCD_READ_UNIT+1
        sys.timerLoopStart(readrcd,1000)
    end    
end
audio.setChannel(1, 0)
--5秒后，开始录音
sys.timerStart(record.start,5000,5,rcdcb)
