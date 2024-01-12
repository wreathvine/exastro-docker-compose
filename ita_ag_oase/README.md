# OASE Agent in Docker Compose  
## 概要   
Docker Compose を利用することで、OASEにデータを送信するためのエージェントを簡単に起動することが可能です。  

## 前提条件


### ハードウェア要件(最小構成)

|              |        |
| ------------ | ------ |
| CPU          | 2Cores |
| メモリ       | 8GB    |
| ディスク容量 | 40GB   |

### ソフトウェア要件 (Docker利用時)

| ソフトウェア  | 動作確認済みバージョン |
| ------------- | ---------------------- |
| Docker Engine | 24                     |
| Git           | 2.31                   |

### ソフトウェア要件 (Podman利用時)

| ソフトウェア   | 動作確認済みバージョン |
| -------------- | ---------------------- |
| Podman Engine  | 4.4                    |
| Docker Compose | 2.20                   |
| Git            | 2.31                   |

## 環境構築

### Git インストール

[Getting Started - Installing Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) の手順に従ってインストールをしてください。

### （Docker利用時）Docker Engine のインストール

[Install Docker Engine](https://docs.docker.com/engine/install/) に従ってインストールをしてください。

### （Podman利用時）Podman Engine のインストール


```
sudo dnf module enable -y container-tools:rhel8

sudo dnf module install -y container-tools:rhel8

sudo dnf -y install podman-docker

podman version
```

### （Podman利用時）Docker Compose のインストール 

[Install Compose standalone](https://docs.docker.com/compose/install/standalone/#on-linux) に従ってインストールをしてください。

## 起動準備
はじめに、各種構成ファイルを取得します。
docker-compose.yml などの起動に必要なファイル群を取得します。

```
git clone https://github.com/exastro-suite/exastro-docker-compose.git
```

以降は、*exastro-docker-compose/ita_ag_oase* ディレクトリで作業をします。  

```shell
cd exastro-docker-compose/ita_ag_oase
```

環境変数の設定ファイル（.env）を、サンプルから作成します。
※値を変更することなく起動が可能ですが、変更を行いたい場合は .envファイルを編集してください。
### （Docker利用時）サンプルからコピー

```shell
cp .env.docker.sample .env
```

### （Podman利用時）サンプルからコピー

```shell
cp .env.podman.sample .env
```


末尾の[パラメータ一覧](#パラメータ一覧)を参考に、起動に必要な環境情報を登録します。


## コンテナ起動


### exastroコンテナの起動方法
*docker* もしくは *docker-compose* コマンドを使いコンテナを起動します。


```shell
# docker コマンドを利用する場合(Docker環境)
docker compose up -d  --wait  

# docker-compose コマンドを利用する場合(Podman環境)
docker-compose up -d  --wait  
```  


## パラメータ一覧

| パラメータ                           | 説明                                                      | 変更                    | デフォルト値・選択可能な設定値              |
| ----------------------------------- | --------------------------------------------------------- | ---------------------- | ----------------------------------------- |

| NETWORK_ID                          | OASE エージェント で利用する Docker ネットワークのID         | 可                     | 20230101                       |
| LOGGING_MAX_SIZE                    | コンテナ毎のログファイルの1ファイルあたりのファイルサイズ      | 可                     | 10m                            |
| LOGGING_MAX_FILE                    | コンテナ毎のログファイルの世代数                             | 可                     | 10                             |
| TZ                                  | OASE エージェント システムで使用するタイムゾーン              | 可                     | Asia/Tokyo                     |
| DEFAULT_LANGUAGE                    | OASE エージェント システムで使用する規定の言語     　         | 可                     | ja                             |
| LANGUAGE                            | OASE エージェント システムで使用する言語                     | 可                     | en                             |
| ITA_VERSION                         | OASE エージェント のバージョン                              | 可                     | 2.3.0                                     |
| UID                                 | OASE エージェント の実行ユーザ                              | 不要                   | **1000** (デフォルト): Docker 利用の場合<br>**0**: Podman 利用の場合     |
| HOST_DOCKER_GID                     | ホスト上の Docker のグループID                             | 不要                    | **999**: Docker 利用の場合<br>**0**: Podman 利用の場合           |
| AGENT_NAME                          | 起動する OASEエージェントの名前                             | 可                     | ita-oase-agent-01                         |
| EXASTRO_URL                         | Exastro IT Automation の Service URL                      | **必須**               | http://localhost:30080                    |
| EXASTRO_ORGANIZATION_ID             | Exastro IT Automation で作成した OrganizationID            | **必須**               | 無し                                      |
| EXASTRO_WORKSPACE_ID                | Exastro IT Automation で作成した WorkspaceID               | **必須**               | 無し                                      |
| EXASTRO_USERNAME                    | Exastro IT Automation で作成した ユーザー名                 | 可                     | admin                                     |
| EXASTRO_PASSWORD                    | Exastro IT Automation で作成した パスワード                                | 可                     | Ch@ngeMe                                  |
| EVENT_COLLECTION_SETTINGS_NAMES     | Exastro IT Automation のOASE管理 エージェント で作成した イベント収集設定名  | **必須**   | 無し※カンマ区切りで複数指定可能   |
| ITERATION                           | OASE エージェント が設定を初期化するまでの、処理の繰り返し数   | 可                     | 10（下限値: 10）                               |
| EXECUTE_INTERVAL                    | OASE エージェント のデータ収集処理の実行間隔                  | 可                    | 5（下限値: 3）                                  |
| LOG_LEVEL                           | OASE エージェント のログレベル                              | 可                     | INFO                                           |
