//@auth
//@req(baseUrl, cronTime)

var scriptName        = getParam("scriptName", "${env.envName}-wp-backup"),
    envName           = getParam("envName", "${env.envName}"),
    envAppid          = getParam("envAppid", "${env.appid}"),
    userId            = getparam("userId", ""),
    backupCount       = getParam("backupCount", "5"),
    isAlwaysUmount    = getParam("isAlwaysUmount"),
    storageNodeId     = getParam("storageNodeId"),
    backupExecNode    = getParam("backupExecNode"),
    storageEnv        = getParam("storageEnv");
    

function run() {
    var BackupManager = use("scripts/backup-manager.js", {
        session           : session,
        baseUrl           : baseUrl,
        uid               : userId,
        cronTime          : cronTime,
        scriptName        : scriptName,
        envName           : envName,
        envAppid          : envAppid,
        backupCount       : backupCount,
        isAlwaysUmount    : isAlwaysUmount,
        storageNodeId     : storageNodeId,
        backupExecNode    : backupExecNode,
        storageEnv        : storageEnv
    });

    api.local.ReturnResult(
        BackupManager.install()
    );
}

function use(script, config) {
    var Transport = com.hivext.api.core.utils.Transport,
        url = baseUrl + "/" + script + "?_r=" + Math.random(),   
        body = new Transport().get(url);
    return new (new Function("return " + body)())(config);
}

try {
    run();
} catch (ex) {
    var resp = {
        result : com.hivext.api.Response.ERROR_UNKNOWN,
        error: "Error: " + toJSON(ex)
    };

    api.marketplace.console.WriteLog("ERROR: " + resp);
    api.local.ReturnResult(resp);
}
