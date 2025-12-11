import org.json.JSONObject;
var Response = com.hivext.api.Response;
var storage_unavailable_markup = "";
var storageInfo = getStorageNodeid();
var storageEnvDomain = storageInfo.storageEnvShortName;
var storageEnvMasterId = storageInfo.storageCtid;
var backupedEnvDomain = '${env.envName}';

resp = api.env.control.GetEnvInfo(storageEnvDomain, session);
if (resp.result != 0 && resp.result != 11) return resp;
if (resp.result == 11) {
    storage_unavailable_markup = "Storage environment " + "${settings.storageName}" + " is deleted.";
} else if (resp.env.status == 1) {
    var backups = api.env.control.ExecCmdById(storageEnvDomain, session, storageEnvMasterId, toJSON([{"command": "/root/getBackups.sh", "params": backupedEnvDomain}]), false).responses[0].out;
    var backupList = toNative(new JSONObject(String(backups))).backups;
    var backupListPrepared = prepareBackups(backupList);
} else {
    storage_unavailable_markup = "Storage environment " + storageEnvDomain + " is unavailable (stopped/sleeping).";
}
      
function getStorageNodeid(){
    let storageEnv = '${settings.storageName}'
    var storageEnvShortName = storageEnv.split(".")[0]
    let resp = api.environment.control.GetEnvInfo({ envName: storageEnvShortName })
    if (resp.result != 0) return resp
    
    let storageNode = resp.nodes.filter(node => (node.nodeGroup == 'storage' && node.ismaster))[0];
    if (!storageNode) return { result: Response.OBJECT_NOT_EXIST, error: "storage node not found" };
    
    return { result: 0, storageCtid : storageNode.id, storageEnvShortName: storageEnvShortName };
}

function prepareBackups(values) {
    var aResultValues = [];
    values = values || [];
    for (var i = 0, n = values.length; i < n; i++) {
        aResultValues.push({
            caption: values[i],
            value: values[i]
        });
    }
    return aResultValues;
}

if (storage_unavailable_markup === "") {
    settings.fields.push({
        "caption": "Backup",
        "type": "list",
        "tooltip": "Select the time stamp for which you want to restore the contents of the web site",          
        "name": "backupDir",
        "required": true,
        "values": backupListPrepared
    })
} else {
    settings.fields.push(
        {"type": "displayfield", "cls": "warning", "height": 30, "hideLabel": true, "markup": storage_unavailable_markup}
    )
}

return settings;
