# cleanup
A simple and unfeatured bash script &amp; crontab template to remove the oldest files in a directory given a desired % threashold to maintain. Intended to be used with Security Onion sensors to replace the iffy clearing mechanism(s) for /nsm/zeek/logs. The defaults in the script will keep the /nsm partition around 90% utilized. There are tons of things this script does not do well. Firstly, it assumes that Zeek logs consume the vast majority of the partition. Sometimes pcaps or Suricata logs are the only concerns, in which case you could probably just change the TARGET_DIR variable to suit. Use this only if you find that the baked-in cleanup functions of Security Onion are not working properly or as expected. Disk quotas are intended to be set in the relevant section(s) of the SOC console: https://docs.securityonion.net/en/2.4/administration.html#configuration

1. Clone the repository in /opt:
```
cd /opt
git clone https://github.com/tellaro-luke/cleanup.git
chmod +x /opt/cleanup/cleanup.sh
```
2. Set up the crontab: `sudo crontab -e`
```
# From https://github.com/tellaro-luke/cleanup
*/1 * * * * /usr/bin/flock -n /tmp/cleanup.sh.lock /opt/cleanup/cleanup.sh
*/10 * * * * cd /opt/cleanup && /usr/bin/git pull
```
---
Optionally, log the output somewhere. Log output is not optimized for SIEM ingestion. `sudo crontab -e`
```
# From https://github.com/tellaro-luke/cleanup
*/1 * * * * /usr/bin/flock -n /tmp/cleanup.sh.lock /opt/cleanup/cleanup.sh > /var/log/cleanup.sh.log
*/10 * * * * cd /opt/cleanup && /usr/bin/git pull
```
You'll also probably want to set up logrotate for this log file:
```
printf "/var/log/cleanup.sh.log {
    size 10M
    rotate 4
    compress
    missingok
    notifempty
    copytruncate
}
" > /etc/logrotate.d/cleanup.sh
sudo logrotate -d /etc/logrotate.d/cleanup.sh
```
