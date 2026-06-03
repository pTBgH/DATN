# Upstream Services Check

## Quick Status

### Service Status
NAME                                           READY   STATUS    RESTARTS   AGE   IP             NODE        NOMINATED NODE   READINESS GATES
candidate-service-67b47b8568-r85hh             4/4     Running   0          67m   10.244.1.201   7189srv02   <none>           <none>
candidate-service-redis-5779df77fd-8nh42       1/1     Running   0          67m   10.244.1.211   7189srv02   <none>           <none>
communication-service-985bfd575-v4bmk          4/4     Running   0          67m   10.244.1.128   7189srv02   <none>           <none>
communication-service-redis-67d556676c-l985l   1/1     Running   0          67m   10.244.1.2     7189srv02   <none>           <none>
hiring-service-7d98f85445-bnscb                4/4     Running   0          67m   10.244.1.16    7189srv02   <none>           <none>
hiring-service-redis-6945dffb4c-m8jqn          1/1     Running   0          67m   10.244.1.232   7189srv02   <none>           <none>
identity-service-7d96b99dd8-t4cfx              4/4     Running   0          67m   10.244.1.173   7189srv02   <none>           <none>
identity-service-redis-5657c455c9-t99mw        1/1     Running   0          67m   10.244.4.250   7189srv05   <none>           <none>
job-service-6c45458cc6-wmjpm                   4/4     Running   0          67m   10.244.1.181   7189srv02   <none>           <none>
job-service-redis-d5457f577-lkjzv              1/1     Running   0          67m   10.244.4.139   7189srv05   <none>           <none>
storage-service-7766d9c786-ndjdw               4/4     Running   0          67m   10.244.2.205   7189srv03   <none>           <none>
storage-service-redis-856cc686ff-cx55b         1/1     Running   0          67m   10.244.4.147   7189srv05   <none>           <none>
workspace-service-5bb465566-bclv6              4/4     Running   0          67m   10.244.4.127   7189srv05   <none>           <none>
workspace-service-redis-b649b57c8-5lfdq        1/1     Running   0          67m   10.244.4.229   7189srv05   <none>           <none>

## Test direct connectivity

### From Kong pod to identity-service
error: Internal error occurred: Internal error occurred: error executing command in container: failed to exec in container: failed to start exec "7863921a3969660cb90127f56adec5369403c30076644ac5e868cc022a03d06a": OCI runtime exec failed: exec failed: unable to start container process: exec: "curl": executable file not found in $PATH
