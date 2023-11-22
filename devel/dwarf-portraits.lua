local utils = require('utils')
local gui = require('gui')

local http = require("socket.http")
local ltn12 = require("ltn12")

local function loadEnv()
    local file = io.open(".env", "r")
    if not file then return end
    for line in file:lines() do
        local key, value = line:match("([^=]+)=([^=]+)")
        if key and value then
            os.setenv(key, value)
        end
    end
    file:close()
end

-- Set Up HTTP Requests

local function makeRequest(url, method, headers, body)
    local response_body = {}
    local res, code, response_headers = http.request {
        url = url,
        method = method,
        headers = headers,
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(response_body),
    }
    return table.concat(response_body), code, response_headers
end

-- OpenAI

local function reformatDescription(str)
    -- [B] tags seem to indicate a new paragraph
    -- [R] tags seem to indicate a sub-blocks of text.Treat them as paragraphs.
    -- [P] tags seem to be redundant
    -- [C] tags indicate color. Remove all color information
    return str:gsub('%[B%]', '\n\n')
        :gsub('%[R%]', '\n\n')
        :gsub('%[P%]', '')
        :gsub('%[C:%d+:%d+:%d+%]', '')
        :gsub('\n\n+', '\n\n')
end

-- Image processing

local function downloadImage(imageUrl)
    local image_data = {}
    http.request {
        url = imageUrl,
        sink = ltn12.sink.table(image_data)
    }
    return table.concat(image_data)
end

local function saveImageToFile(imageData, filePath)
    local file = io.open(filePath, "wb") -- "wb" mode writes in binary
    if file then
        file:write(imageData)
        file:close()
    else
        error("Could not open file " .. filePath .. " for writing.")
    end
end

-- Process item description

local item = dfhack.gui.getSelectedItem(true)
local itemRawName = dfhack.items.getDescription(item, 0, false)
local itemRawDescription = df.global.game.main_interface.view_sheets.raw_description

local itemName = dfhack.df2utf(itemRawName)
local itemDescription = reformatDescription(dfhack.df2utf(itemRawDescription))

-- Integrate OpenAI API Calls

loadEnv()
local apiKey = os.getenv("OPENAI_API_KEY")

local headers = {
    ["Authorization"] = "Bearer " .. apiKey,
    ["Content-Type"] = "application/json"
}

local requestBody = {
    model = "dall-e-3",
    prompt = itemDescription,
    size = "256x256",
    quality = "standard",
    n = 1
}

local url = "https://api.openai.com/v1/images/generate"
local response, code = makeRequest(url, "POST", headers, json.encode(requestBody))

local imageUrl = response.data[0].url

saveImageToFile(downloadImage(imageUrl), 'dall-e')
