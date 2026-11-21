{ config, lib, ... }:
{
  services.grafana.provision.alerting = {
    contactPoints.settings = {
      apiVersion = 1;
      contactPoints = [{
        orgId = 1;
        name = "matrix";
        receivers = [{
          uid = "matrix-sirenhead";
          type = "webhook";
          settings = {
            url = "http://${lib.head config.services.python-http-handlers.sirenhead.listenStreams}/";
            httpMethod = "POST";
          };
        }];
      }];
    };

    policies.settings = {
      apiVersion = 1;
      policies = [{
        orgId = 1;
        receiver = "matrix";
        group_by = [ "grafana_folder" "alertname" ];
        group_wait = "30s";
        group_interval = "5m";
        repeat_interval = "12h";
      }];
    };
  };
}
