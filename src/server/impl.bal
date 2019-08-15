import ballerina/http;
import ballerina/config;
import ballerina/filePath as path;
import ballerina/system;
import ballerina/internal;
import ballerina/log;

const string header = "<html><head></head></body><h1>Folders</h1><ul>";
const string footer = "</ul></body></html>";
final string mountPath = config:getAsString("mount_path");

@http:ServiceConfig {
    basePath: "/"
}
service hello on new http:Listener(9090) {

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/*"
    }
    resource function getFile(http:Caller caller, http:Request req) {
        http:Response res = new;
        string reqPath = req.rawPath;
        log:printDebug("reqPath: " + reqPath);
        if (internal:contains(reqPath, "..")) {
            // if invalid path is given
            res.statusCode = 400;
            res.setTextPayload("invalid path");
        } else {
            // change path separator
            log:printDebug("cleaned reqPath: " + reqPath);
            string|error file = path:build(mountPath, reqPath);
            if (file is error) {
                res.statusCode = 500;
                res.setTextPayload("error reading from: " + reqPath);
            } else {
                file = checkpanic http:decode(internal:replaceAll(file, "\\\\", "/"), "UTF-8");
                log:printDebug("file: " + file);
                if (system:exists(file)) {
                    if (isDirectory(file)) {
                        log:printDebug("Directory found.");
                        // if directory
                        string|error directoryContent = getDirectoryView(file, reqPath, mountPath);
                        if (directoryContent is error) {
                            res.statusCode = 500;
                            res.setTextPayload("error reading directory");
                        } else {
                            res.statusCode = 200;
                            res.setTextPayload(directoryContent);
                            res.setContentType("text/html; charset=utf-8");
                        }
                    } else {
                        // if file
                        log:printInfo("File found.");
                        res.statusCode = 200;
                        res.setFileAsPayload(file);
                    }
                } else {
                    res.statusCode = 404;
                    res.setTextPayload("file/directory not found");
                }
            }
        }

        error? respondErr = caller->respond(res);
        if (respondErr is error) {
            log:printError("error sending response", respondErr);
        }
    }
}

function getDirectoryView(string path, string requestPath, string mountPath) returns string|error {
    string content = header;
    system:FileInfo[] files = check system:readDir(path);
    log:printDebug("=========================================================");
    log:printDebug("PATH:" + path);
    log:printDebug("MOUNT:" + mountPath);
    log:printDebug("PATH PARENT:" + check path:parent(path));
    if (!(internal:replace(path, mountPath, "") == "" || internal:replace(path, mountPath, "") == "/")) {
        content += "<li><a href=\"" + check path:parent(requestPath) + "\">../</a></li>";
    }

    foreach system:FileInfo file in files {
        string isDirectory = file.isDir() ? "true" : "false";
        log:printInfo(file.getName() + " - " + isDirectory);
        content += "<li><a href=\"" + check path:build(requestPath, file.getName()) + "\">" + file.getName() + "</a></li>";
    }
    log:printDebug("=========================================================");
    return content + footer;
}

function isDirectory(string path) returns boolean {
    return system:readDir(path) is error ? false : true;
}
