#!/usr/bin/env bash

http_status_codes=(
    ["100"]="Continue|The server has received the request headers and the client should proceed to send the request body."
    ["101"]="Switching Protocols|The server is switching protocols as requested by the client."
    ["102"]="Processing|The server has received and is processing the request, but no response is available yet."
    ["103"]="Early Hints|Used to provide some response headers before the final HTTP message."
    ["200"]="OK|The request was successful."
    ["201"]="Created|The request was successful and a new resource was created."
    ["202"]="Accepted|The request was accepted for processing, but the processing is not complete."
    ["203"]="Non-Authoritative Information|The request was successful, but the returned information is from another source."
    ["204"]="No Content|The request was successful, but there is no content to return."
    ["205"]="Reset Content|The request was successful, and the client should reset the document view."
    ["206"]="Partial Content|The request was successful, and the response contains a partial representation of the resource."
    ["207"]="Multi-Status|The response contains information about multiple independent operations."
    ["208"]="Already Reported|The members of a DAV binding have already been enumerated in a previous response."
    ["226"]="IM Used|The server has fulfilled a GET request for the resource, and the response is a representation of the result."
    ["300"]="Multiple Choices|The request has more than one possible response."
    ["301"]="Moved Permanently|The resource has been permanently moved to a new URL."
    ["302"]="Found|The resource has been temporarily moved to a new URL."
    ["303"]="See Other|The response to the request can be found under a different URL."
    ["304"]="Not Modified|The requested resource has not been modified since the last request."
    ["305"]="Use Proxy|The requested resource must be accessed through the proxy given by the Location field."
    ["307"]="Temporary Redirect|The resource has been temporarily moved to a new URL."
    ["308"]="Permanent Redirect|The resource has been permanently moved to a new URL."
    ["400"]="Bad Request|The server could not understand the request due to invalid syntax."
    ["401"]="Unauthorized|The client must authenticate itself to get the requested response."
    ["402"]="Payment Required|Reserved for future use."
    ["403"]="Forbidden|The client does not have access rights to the content."
    ["404"]="Not Found|The server can not find the requested resource."
    ["405"]="Method Not Allowed|The request method is not supported for the requested resource."
    ["406"]="Not Acceptable|The requested resource is only capable of generating content not acceptable according to the Accept headers sent in the request."
    ["407"]="Proxy Authentication Required|The client must first authenticate itself with the proxy."
    ["408"]="Request Timeout|The server timed out waiting for the request."
    ["409"]="Conflict|The request could not be completed due to a conflict with the current state of the resource."
    ["410"]="Gone|The requested resource is no longer available at the server."
    ["411"]="Length Required|The server refuses to accept the request without a defined Content-Length."
    ["412"]="Precondition Failed|The precondition given in one or more of the request-header fields evaluated to false."
    ["413"]="Payload Too Large|The server is refusing to process a request because the request payload is larger than the server is willing or able to process."
    ["414"]="URI Too Long|The server is refusing to process a request because the request URI is longer than the server is willing to interpret."
    ["415"]="Unsupported Media Type|The server is refusing to service the request because the entity of the request is in a format not supported by the requested resource for the request method."
    ["416"]="Range Not Satisfiable|The server cannot serve the requested byte range."
    ["417"]="Expectation Failed|The expectation given in the request's Expect header field could not be met."
    ["421"]="Misdirected Request|The request was directed at a server that is not able to produce a response."
    ["422"]="Unprocessable Entity|The request was well-formed but was unable to be followed due to semantic errors."
    ["423"]="Locked|The resource that is being accessed is locked."
    ["424"]="Failed Dependency|The request failed due to failure of a previous request."
    ["425"]="Too Early|The server is unwilling to risk processing a request that might be replayed."
    ["426"]="Upgrade Required|The server refuses to perform the request using the current protocol but might be willing to do so after the client upgrades to a different protocol."
    ["428"]="Precondition Required|The origin server requires the request to be conditional."
    ["429"]="Too Many Requests|The user has sent too many requests in a given amount of time."
    ["431"]="Request Header Fields Too Large|The server is unwilling to process the request because its header fields are too large."
    ["451"]="Unavailable For Legal Reasons|The server is denying access to the resource as a consequence of a legal demand."
    ["500"]="Internal Server Error|The server encountered an unexpected condition that prevented it from fulfilling the request."
    ["501"]="Not Implemented|The server does not support the functionality required to fulfill the request."
    ["502"]="Bad Gateway|The server, while acting as a gateway or proxy, received an invalid response from the upstream server."
    ["503"]="Service Unavailable|The server is currently unable to handle the request due to a temporary overload or scheduled maintenance."
    ["504"]="Gateway Timeout|The server, while acting as a gateway or proxy, did not receive a timely response from the upstream server."
    ["505"]="HTTP Version Not Supported|The server does not support the HTTP protocol version used in the request."
    ["506"]="Variant Also Negotiates|The server has an internal configuration error: the chosen variant resource is configured to engage in transparent content negotiation itself."
    ["507"]="Insufficient Storage|The server is unable to store the representation needed to complete the request."
    ["508"]="Loop Detected|The server detected an infinite loop while processing the request."
    ["510"]="Not Extended|Further extensions to the request are required for the server to fulfill it."
    ["511"]="Network Authentication Required|The client needs to authenticate to gain network access."
)

echo_info() {
  printf "[INFO] %s\n" "$1"
}

echo_success() {
  printf "[SUCCESS] %s\n" "$1"
}

generate_error_page() {
  local error_code="$1"
  local error_description="$2"
  local full_description="$3"

  # Use sed to replace the content inside the specified HTML elements
  sed -e "s/<title>.*<\/title>/<title>$error_code: $error_description<\/title>/" \
      -e "s/<h3>.*<\/h3>/<h3>Error $error_code<\/h3>/" \
      -e "s/<p class=\"description\">.*<\/p>/<p class=\"description\">$full_description<\/p>/" \
      "./template.html" > "./errors/$error_code.html"
}

echo_info "Starting to generate errors"

mkdir -p "./errors"

for error_code in "${!http_status_codes[@]}"; do
    error_description="${http_status_codes[$error_code]%%|*}"
    full_description="${http_status_codes[$error_code]#*|}"

    generate_error_page "$error_code" "$error_description" "$full_description"
done

echo_success "Errors generated successfully"
