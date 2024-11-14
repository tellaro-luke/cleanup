# cleanup
## Description
A simple and unfeatured bash script &amp; crontab template to remove the oldest files in a directory given a desired % threashold to maintain. Intended to be used with Security Onion sensors to replace the iffy clearing mechanism(s) for /nsm/zeek/logs. The defaults in the script will keep the /nsm partition around 90% utilized. There are tons of things this script does not do well. Firstly, it assumes that Zeek logs consume the vast majority of the partition. Sometimes pcaps or Suricata logs are the only concerns, in which case you could probably just change the TARGET_DIR variable to suit. Use this only if you find that the baked-in cleanup functions of Security Onion are not working properly or as expected. Disk quotas are intended to be set in the relevant section(s) of the SOC console: https://docs.securityonion.net/en/2.4/administration.html#configuration

By default the script is set to run in DEBUG mode. This is intentional because you should definately run it in debug mode at least once before you let it loose to do its thing. Each directory has a designated percentage of the total allowed usage within the specified directories. When a directory exceeds its quota, the script removes files in batches to bring its usage back within the target, maintaining a balanced distribution of space according to predefined quotas. This makes it possible for the buffer space - which is occupied by other files in the partition - to expand and contract as needed while the total quota (ACTION_THRESHOLD) is enforced. 

## Visual Example
In this example, ACTION_THRESHOLD=90, and it doesn't matter what is in the TARGET_DIRS array.
```
|-------10%-------|------------------------------------------90%-------------------------------------------| -> Example showing percentages of total disk (partition)
|--<always_free>--|--<other_files>--|------------------------<space_for_set_quotas>------------------------| -> other_files takes a small amount of the quota
|--<always_free>--|--------<other_files>--------|------------------<space_for_set_quotas>------------------| -> other_files takes a medium amount of the quota
|--<always_free>--|------------------<other_files>------------------|--------<space_for_set_quotas>--------| -> other_files takes a large amount of the quota
|--<always_free>--|-------------------------------------<other_files>-------------------------------------|| -> other_files takes the total amount of the quota
```
Next, consider the settings:
```
TARGET_DIRS=("/nsm/pcap" "/nsm/zeek/logs")
TARGET_QUOTAS=("30" "70")
ACTION_THRESHOLD=90
```
This visualization is the ideal distribution of storage if /nsm/pcap and /nsm/zeek/logs are the main contributers to the used space on the /nsm partition. 
```
|--<always_free>--|--<other_files>--|-----</nsm/pcap>-----|----------------</nsm/zeek/logs>----------------|
```
Note: _If other_files consumes most or all of the available quota, consider adding the largest unspecified dirs to TARGET_DIRS_

## Setup
1. Clone the repository in /opt:
```
cd /opt
git clone https://github.com/tellaro-luke/cleanup.git
chmod +x /opt/cleanup/cleanup.sh
```
2. Update the variables at the start of the script according to your needs: `sudo vim /opt/cleanup/cleanup.sh`
3. Set up the crontab: `sudo crontab -e`
```
# From https://github.com/tellaro-luke/cleanup
*/1 * * * * /usr/bin/flock -n /tmp/cleanup.sh.lock /opt/cleanup/cleanup.sh
```
---
Optionally, log the output somewhere. Log output is not optimized for SIEM ingestion. `sudo crontab -e`
```
# From https://github.com/tellaro-luke/cleanup
*/1 * * * * /usr/bin/flock -n /tmp/cleanup.sh.lock /opt/cleanup/cleanup.sh > /var/log/cleanup.sh.log
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
