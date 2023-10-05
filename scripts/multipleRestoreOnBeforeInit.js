import org.json.JSONObject;
var Response = com.hivext.api.Response;
var storage_unavailable_markup = "";
var storageInfo = getStorageNodeid();
var storageEnvDomain = storageInfo.storageEnvShortName;
var storageEnvMasterId = storageInfo.storageCtid;

resp = api.env.control.GetEnvInfo(storageEnvDomain, session);
if (resp.result != 0 && resp.result != 11) return resp;
if (resp.result == 11) {
       storage_unavailable_markup = "Storage environment " + "${settings.storageName}" + " is deleted.";
} else if (resp.env.status == 1) {
    var respUpdate = api.env.control.ExecCmdById(storageEnvDomain, session, storageEnvMasterId, toJSON([{"command": "/usr/bin/restic self-update 2>&1", "params": ""}]), false);
    if (respUpdate.result != 0) return resp;
    var backups = api.env.control.ExecCmdById(storageEnvDomain, session, storageEnvMasterId, toJSON([{"command": "/root/getBackupsAllEnvs.sh", "params": ""}]), false);
    if (backups.result != 0) return resp;
    var backupList = toNative(new JSONObject(String(backups.responses[0].out)));
    var envs = prepareEnvs(backupList.envs);
    var backups = prepareBackups(backupList.backups);
} else {
    storage_unavailable_markup = "Storage environment " + storageEnvDomain + " is unavailable (stopped/sleeping).";
}
      
function getStorageNodeid(){
    let storageEnv = '${settings.storageName}';
    var storageEnvShortName = storageEnv.split(".")[0];
    let resp = api.environment.control.GetEnvInfo({ envName: storageEnvShortName });
    if (resp.result != 0) return resp;
    
    let storageNode = resp.nodes.filter(node => (node.nodeGroup == 'storage' && node.ismaster))[0];
    if (!storageNode) return { result: Response.OBJECT_NOT_EXIST, error: "storage node not found" };
    
    return { result: 0, storageCtid : storageNode.id, storageEnvShortName: storageEnvShortName };
}

function prepareEnvs(values) {
    var aResultValues = [];

    values = values || [];

    for (var i = 0, n = values.length; i < n; i++) {
        aResultValues.push({ caption: values[i], value: values[i] });
    }

    return aResultValues;
}

function prepareBackups(backups) {
    var oResultBackups = {};
    var aValues;

    for (var envName in backups) {
        if (Object.prototype.hasOwnProperty.call(backups, envName)) {
            aValues = [];

            for (var i = 0, n = backups[envName].length; i < n; i++) {
                aValues.push({ caption: backups[envName][i], value: backups[envName][i] });
            }

            oResultBackups[envName] = aValues;
        }
    }

    return oResultBackups;
}

if (storage_unavailable_markup === "") {
    settings.fields.push({
            "caption": "Restore from",
            "type": "list",
            "name": "backupedEnvName",
            "required": true,
            "values": envs
        }, {
            "caption": "Backup",
            "type": "list",
            "name": "backupDir",
            "required": true,
	    "tooltip": "Select the time stamp for which you want to restore the DB dump",
            "dependsOn": {
                "backupedEnvName" : backups
            }
        })
} else {
    settings.fields.push(
        {"type": "displayfield", "cls": "warning", "height": 30, "hideLabel": true, "markup": storage_unavailable_markup}
    )
}

return settings;
