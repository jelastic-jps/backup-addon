import org.json.JSONObject;
var storage_unavailable_markup = "";
var storageInfo = getStorageNodeid();
var storageEnvDomain = storageInfo.storageEnvShortName;
var storageEnvMasterId = storageInfo.storageNodeId;

resp = jelastic.env.control.GetEnvInfo(storageEnvDomain, session);
if (resp.result != 0 && resp.result != 11) return resp;
if (resp.result == 11) {
       storage_unavailable_markup = "Storage environment " + "${settings.storageName}" + " is deleted.";
} else if (resp.env.status == 1) {
    var backups = jelastic.env.control.ExecCmdById(storageEnvDomain, session, storageEnvMasterId, toJSON([{"command": "/root/getBackupsAllEnvs.sh", "params": ""}]), false, "root").responses[0].out;
    var backupList = toNative(new JSONObject(String(backups)));
    var envs = prepareEnvs(backupList.envs);
    var backups = prepareBackups(backupList.backups);
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
