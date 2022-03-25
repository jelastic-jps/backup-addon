import org.json.JSONObject;
var storage_unavailable_markup = "";
var storageInfo = getStorageNodeid();
var storageEnvDomain = storageInfo.storageEnvShortName;
var storageEnvMasterId = storageInfo.storageNodeId;
var backupedEnvDomain = '${env.envName}';

resp = jelastic.env.control.GetEnvInfo(storageEnvDomain, session);
if (resp.result != 0 && resp.result != 11) return resp;
if (resp.result == 11) {
    storage_unavailable_markup = "Storage environment " + storageEnvDomain + " is deleted.";
} else if (resp.env.status == 1) {
    var backups = jelastic.env.control.ExecCmdById(storageEnvDomain, session, storageEnvMasterId, toJSON([{"command": "/root/getBackups.sh", "params": backupedEnvDomain}]), false, "root").responses[0].out;
    var backupList = toNative(new JSONObject(String(backups))).backups;
    var backupListPrepared = prepareBackups(backupList);
} else {
    storage_unavailable_markup = "Storage environment " + storageEnvDomain + " is unavailable (stopped/sleeping).";
}
      
function getStorageNodeid(){
    var storageEnv = '${settings.storageName}'
    var storageEnvShortName = storageEnv.split(".")[0]
    var resp = jelastic.environment.control.GetEnvInfo(storageEnvShortName, session)
    if (resp.result != 0) return resp
    for (var i = 0; resp.nodes; i++) {
        var node = resp.nodes[i]
        if (node.nodeGroup == 'storage' && node.ismaster) {
            return { result: 0, storageNodeId: node.id, storageEnvShortName: storageEnvShortName };
        }
    }
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
