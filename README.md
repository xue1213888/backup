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
```shell
docker run --rm --env-file .env -v /root/data/test:/data xue1213888/backup:v0.0.1 --restore latest
```
