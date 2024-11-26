# 原理

> 填写 `B2_DOWNLOAD_URL` 后，会从 cloudflare 获取文件，免除流量出口费用。

使用`rclone`管理`b2`网盘。使用`restic`与`rclone`进行备份。

其实就只有一个 `entry.sh` 脚本，你们翻着看一下，非常简单。

1. 脚本就是初始化了一下环境，然后循环备份。

# 下载
```shell
docker pull xue1213888/backup:v0.0.1
```


# 开启备份
```shell
docker run -d -v /root:/data --env-file .env --name restic-backup xue1213888/backup:v0.0.1 --backup
```

# 恢复数据到指定目录

配置文件保存好，你只需要拉取镜像，使用相同的配置文件，无论你在哪台机器，你都能顺利拉取到你备份上去的数据。
最后面那个 latest 是你保存的快照版本，意思是恢复到最新保存的那个。
如果你要指定版本，就把最后的latest去掉，执行一次，输出的内容里面会有你所有的快照版本，然后你再选择一个版本号，填到后面就行了。
```shell
docker run --rm --env-file .env -v /root/data/test:/data xue1213888/backup:v0.0.1 --restore latest
```


# 配置描述
```shell
B2_BUCKET=<存储桶名字,必填>
B2_PATH=<B2存储桶存放路径,必填>
B2_ACCOUNT=<application key id,必填>
B2_KEY=<application key,必填>

# 是否硬删除
B2_HARD_DELETE=<true/false,默认false>
# 免流下载地址，套了 cf worker 就可以免流，b2官方就有教程，可以留空
B2_DOWNLOAD_URL=<下载地址，带协议并且不带尾巴，比如:https://abc.com>

# 自己设定呢，但是不要跟给忘了，其他地方想要拉这个备份都需要密码
RESTIC_PASSWORD=<仓库密码,必填>
# 备份时间间隔，单位h
BACKUP_INTERVAL=6
# 备份版本数量保留，超过这个数量就会删除最早的备份
BACKUP_KEEP_LAST=4

# 主机名，不写也行
RESTIC_HOST=xsc-docker-restic
```