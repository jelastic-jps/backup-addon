var STORAGE_NODE_DISK_LIMITATION = "storage.node.disk.limitation",
    SAME_NODES = "environment.maxsamenodescount",
    MAX_NODES = "environment.maxnodescount";

var max = 7, min = 1, resp, name, value, minStorageSize = 5, maxStorageSize ;

var hasCollaboration = (parseInt('${fn.compareEngine(7.0)}', 10) >= 0),
    q = [];

if (hasCollaboration) {
    quotas = [
        { quota : { name: MAX_NODES }, value: parseInt('${quota.environment.maxnodescount}', 10) },
        { quota : { name: SAME_NODES }, value: parseInt('${quota.environment.maxsamenodescount}', 10) },
        { quota : { name: STORAGE_NODE_DISK_LIMITATION }, value: parseInt('${quota.storage.node.disk.limitation}', 10) }
    ];
} else {
    quotas = jelastic.billing.account.GetQuotas(STORAGE_NODE_DISK_LIMITATION + ";" + SAME_NODES + ";" + MAX_NODES).array || [];
}

for (var i = 0, n = quotas.length; i < n; i++) {
  name = quotas[i].quota.name;
  value = quotas[i].value;
  
  if (max >= value) {
    if (name == MAX_NODES) max = value ? value - 1 : 1;
      else if (name == SAME_NODES) max = value;
  }
  if (name == STORAGE_NODE_DISK_LIMITATION) maxStorageSize = parseInt(value/1000);
}

return {
  "result": 0,
  "settings": {
    "fields": [
      {
        "type": "radio-fieldset",
        "name": "customName",
        "hidden": false,
        "default": "1",
        "values": {
          "1": "Standalone",
          "2": "Cluster"
        },
        "showIf": {
          "2": [
            {
              "type": "spinner",
              "name": "storageNodesCount",
              "caption": "Number of nodes",
              "min": 3,
              "max": max,
              "increment": 2
            },
            {
              "type": "string",
              "name": "clustered",
              "value": true,
              "inputType": "hidden"
            }
          ]
        }
      },
      {
        "type": "spinner",
        "name": "storageSize",
        "caption": "Storage size, GB",
        "min": 5,
        "max": maxStorageSize,
        "default": maxStorageSize,
        "increment": 1
      },
      {
        "caption": "Regions",
        "type": "regionlist",
        "name": "regions",
        "disableInactive": true,
        "selectFirstAvailable": true,
        "dependsOn": "owner"
      },
      {
        "caption": "Environment",
        "type": "envname",
        "name": "envName",
        "dependsOn": "region"
      },
      {
        "caption": "Owner",
        "type": "owner",
        "name": "owner"
      }
    ]
  }
};
