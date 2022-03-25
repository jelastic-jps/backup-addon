//@auth

var action = getParam("action", "backup"),
    baseUrl = "${baseUrl}";

function run() {
    var BackupManager = use("scripts/backup-manager.js", {
        session           : session,
        baseUrl           : baseUrl,
        uid               : user.uid,
        cronTime          : "${cronTime}",
        scriptName        : "${scriptName}",
        envName           : "${envName}",
        envAppid          : "${envAppid}",
        storageNodeId     : "${storageNodeId}",
        backupExecNode 	  : "${backupExecNode}",
        backupCount       : "${backupCount}",
        storageEnv        : "${storageEnv}"
    });

    jelastic.local.ReturnResult(
        BackupManager.invoke(action)
    );
}

function use(script, config) {
    var Transport = com.hivext.api.core.utils.Transport,
        body = new Transport().get(baseUrl + "/" + script + "?_r=" + Math.random());
    var debug = baseUrl + "/" + script + "?_r=" + Math.random();

    return new (new Function("return " + body)())(config);
}

try {
    run();
} catch (ex) {
    var resp = {
        result : com.hivext.api.Response.ERROR_UNKNOWN,
        error: "Error: " + toJSON(ex)
    };

    jelastic.marketplace.console.WriteLog(appid, signature, "ERROR: " + resp);
    jelastic.local.ReturnResult(resp);
}
