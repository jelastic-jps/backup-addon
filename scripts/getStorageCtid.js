var storageEnv = '${globals.storageEnv}'
var storageEnvShortName = storageEnv.split(".")[0]
var resp = jelastic.environment.control.GetEnvInfo(storageEnvShortName, session)
if (resp.result != 0) return resp
for (var i = 0; resp.nodes; i++) {
    var node = resp.nodes[i]
    if (node.nodeGroup == 'storage' && node.ismaster) {
        return { result: 0, storageCtid : node.id, storageEnvShortName : storageEnvShortName};
    }
}
