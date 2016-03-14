---
layout: post
title: Backend proxy with genymotion and WireMock
categories: android
---

Often you are working on an app that is supposed to be backed by an API, but the API is non-existent or not ready. This should not deter you from continuing development.

With [WireMock](http://wiremock.org/) you can mock your API by providing stubs for the different requests that are coming from your app and you can configure your emulator to use your the mock server as a proxy for the requests. For this tutorial, i use [genymotion](https://www.genymotion.com/), as a preferred emulator.

Assuming for the app you are building, you want to capture the preferred way our customers want to communicate with you, your endpoint for the different communication options would be something like `http://myapp.com/api/communicationmethods` and it's response would be;

```json
[
  {
    "id": "4e49f1f4-0179-4030-9401-6df53b05223c",
    "name": "WhatsApp"
  },
  {
    "id": "9a379c51-5f9c-49e1-a6fc-facf044798fb",
    "name": "Telephone"
  },
  {
    "id": "8e807572-9556-474a-ba0b-bff8d3da592b",
    "name": "SMS"
  },
  {
    "id": "f4874dd6-1644-484b-9c82-6b25bc2218ec",
    "name": "Email"
  },
  {
    "id": "9f99afcf-c450-45fe-a118-0594a2de8b57",
    "name": "Courier"
  }
]
```

With WireMock, you create a stub (*which is a predefined responses for requests that meet a certain criteria i.e. URL, headers and body content*) as below;

```json
{
  "request": {
    "method": "GET",
    "url": "/api/communicationmethods"
  },
  "response": {
    "status": 200,
    "body": "\r\n  {\r\n    \"id\": \"4e49f1f4-0179-4030-9401-6df53b05223c\",\r\n    \"name\": \"WhatsApp\"\r\n  },\r\n  {\r\n    \"id\": \"9a379c51-5f9c-49e1-a6fc-facf044798fb\",\r\n    \"name\": \"Telephone\"\r\n  },\r\n  {\r\n    \"id\": \"8e807572-9556-474a-ba0b-bff8d3da592b\",\r\n    \"name\": \"SMS\"\r\n  },\r\n  {\r\n    \"id\": \"f4874dd6-1644-484b-9c82-6b25bc2218ec\",\r\n    \"name\": \"Email\"\r\n  },\r\n  {\r\n    \"id\": \"9f99afcf-c450-45fe-a118-0594a2de8b57\",\r\n    \"name\": \"Courier\"\r\n  }\r\n]",
    "headers": {
      "Content-Type": "application/json"
    }
  }
}
```

To see how this works,

1. Open your terminal
2. Create a folder called `wiremock/mappings` by running `mkdir -p wiremock/mappings`
3. Save the above stub into the `wiremock/mappings` folder; you can do this by creating a text file with the `.json` extension and pasting the above stub into it.
4. Download WireMock from [here](http://repo1.maven.org/maven2/com/github/tomakehurst/wiremock/1.57/wiremock-1.57-standalone.jar) into the `wiremock` folder.
```
wget http://repo1.maven.org/maven2/com/github/tomakehurst/wiremock/1.57/wiremock-1.57-standalone.jar
```
5. Start WireMock is standalone mode; by running `java -jar wiremock-1.57-standalone.jar --port 8888 --verbose`

WireMock by default expects to find a `mappings` folder in the current directory it's running. You can change the source of the mappings directory by specifying the `--root-dir` flag when starting WireMock. i.e.
`java -jar wiremock-1.57-standalone.jar --port 8888 --verbose --root-dir /some_directory`

When WireMock starts, you should having something like this.

![WireMock screenshot](/images/wiremock-screenshot.png)

You can test that this is working successfully by running on the terminal;

`curl -X GET http://localhost:8888/api/communicationmethods`

You can find more information about how WireMock stubbing works [here](http://wiremock.org/stubbing.html)


Now that you have successfully configured WireMock, you need to configure your emulator to use WireMock as a proxy. To do this,

1. Go to Android Settings  
![Android Settings](/images/backend-proxy-android-settings.png)

2. Under Wireless & Networks section, select Wi-Fi  
![Android Wi-Fi Settings Option](/images/backend-proxy-android-wifi-settings-menu.png)

3. Press and Hold WiredSSID network until a dialog shows up.
4. Select Modify Network, Check **advanced options** and Select Manual for Proxy Settings menu entry
7. Enter the proxy settings as below and press the Save button  
    1. Ip: 10.0.3.2 (Special Ip genymotion uses to connect to host.)
    2. Port: 8888 (Port configured for WireMock)
![Android Manual Proxy Settings](/images/backend-proxy-android-proxy-settings.png)

With this, the emulator can now connect to the WireMock server. You can test this by opening the browser in the emulator and visiting any host that ends with `/api/communicationmethods`. In my emulator, i visited `http://localhost/api/communicationmethods` and my response was as configured in the stub above.

![Android WireMock Response](/images/backend-proxy-android-browser-response.png)

*Please Note: the localhost part in the URL above can be substituted for any other host and it should work.*

Give it a shot and let me know what you think.
