# Exastro IT Automation in Docker Compose  
このdocker-composeは、Dockerを使用し Exastro IT Automation を起動して実行できるようにします。  
  - (based on [exastro-it-automation](https://github.com/exastro-suite/exastro-it-automation))  
  - (based on [exastro-platform](https://github.com/exastro-suite/exastro-platform))  
  

## 概要   
Exastro IT Automation の起動には、プロファイル (*--profile*) によって対象を指定することで、環境ごとに起動するコンテナを選択することが可能です。  


| プロファイル名 | 対象となるコンテナ                                 | スケーリング                  |
| -------------- | -------------------------------------------------- | ----------------------------- |
| all            | すべてのコンテナ                                   |                               |
| common         | MariaDB、GitLab、Keycloak コンテナ                 | 不可 (対応予定)               |
| mariadb        | MariaDB コンテナ                                   | 不可 (対応予定)               |
| gitlab         | GitLab コンテナ                                    | 不可 (対応予定)               |
| keycloak       | Keycloak コンテナ                                  | 不可 (対応予定)               |
| platform       | Exastro Platform 関連のコンテナ                    | 可能                          |
| ita            | Exastro IT Automation 関連のコンテナ               | 一部可能                      |
| web            | Web 系のコンテナ                                   | 可能                          |
| migration      | インストール・アップグレード用コンテナ             | 不可 (必ず同時に1つのみ起動)  |
| backyard       | Backyard 関連のコンテナ                            | 不可 (対応予定)               |
| batch          | バッチ処理関連のコンテナ(Crontabに登録が必要)      | 不可 (不要)                   |


## 起動準備
はじめに、各種構成ファイルを取得します。
docker-compose.yml などの起動に必要なファイル群を取得します。

```
git clone https://github.com/exastro-suite/exastro-docker-compose.git
```

以降は、*exastro-docker-compose* ディレクトリで作業をします。  

```shell
cd exastro-docker-compose
```

環境変数のサンプルファイルからコピーします。

```shell
cp .env.sample .env  # 値を変更することなく起動が可能ですが、変更を行いたい場合は .envファイルを編集してください。  
```

末尾のパラメータ一覧を参考に、起動に必要な環境情報を登録します。

```
# ENCRYPT_KEY の作成は以下のコマンドを参考にしてください。
head -c 32 /dev/urandom | base64
```


## コンテナ起動

*docker* もしくは *docker-compose* コマンドを使いコンテナを起動します。
この例では、**all** プロファイルを指定することで、すべてのコンテナを一度に起動します。

```shell
# docker コマンドを利用する場合(Docker環境)
docker compose --profile all up -d  

# docker-compose コマンドを利用する場合(Podman環境)
docker-compose --profile all up -d  
```  

## Organization作成とアクセス

### 設定例

| 設定項目                      | 設定値                  |
| ----------------------------- | ----------------------- |
| システム管理者                | admin                   |
| システム管理者パスワード      | password                |
| Organization ID               | sample-org              |
| Organization 管理者           | admin                   |
| Organization 管理者パスワード | password                |
| EXTERNAL_URL_PROTOCOL         | http                    |
| EXTERNAL_URL_HOST             | exastro.example.com     |
| EXTERNAL_URL_PORT             | 81                      |
| EXTERNAL_URL_MNG_PROTOCOL     | http                    |
| EXTERNAL_URL_MNG_HOST         | exastro-mng.example.com |
| EXTERNAL_URL_MNG_PORT         | 80                      |
| GITLAB_PROTOCOL               | http                    |
| GITLAB_HOST                   | gitlab.example.com      |
| GITLAB_PORT                   | 40080                   |


### Organization 作成

```shell
BASE64_BASIC=$(echo -n "admin:password" | base64)
BASE_URL=http://exastro-mng.example.com:81


curl -X 'POST' "${BASE_URL}/api/platform/organizations" -H 'accept: application/json' -H "Authorization: Basic ${BASE64_BASIC}" -H 'Content-Type: application/json' -d '{
  "id": "sample-org",
  "name": "Sample organization",
  "organization_managers": [
    {
      "username": "admin",
      "email": "admin@example.com",
      "firstName": "admin",
      "lastName": "admin",
      "credentials": [
        {
          "type": "password",
          "value": "password",
          "temporary": true
        }
      ],
      "requiredActions": [
        "UPDATE_PROFILE"
      ],
      "enabled": true
    }
  ],
  "plan": {},
  "options": {
    "sslRequired": "None"
  },
  "optionsIta": {}
}'
```
  

### 各ページのURL  
#### システム管理者用コンソール  
http://exastro-mng.example.com:81/auth/  
  
#### Organization ページ  
http://exastro.example.com:80/sample-org/platform/  
  
#### Gitlab  
http://gitlab.example.com:40080  
  

## パラメータ一覧

| パラメータ                              | 説明                                                                        | 変更                          | デフォルト値・選択可能な設定値                                                                          |
| --------------------------------------- | --------------------------------------------------------------------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------- |
| COMPOSE_PROJECT_NAME                    | Docker Compose におけるプロジェクト名                                       | 可                            | exastro                                                                                                 |
| COMPOSE_PROFILES                        | Docker Compose におけるプロファイル名<br>指定するプロファイルは上記を参照。 | 可                            | all                                                                                                     |
| NETWORK_ID                              | Exastro で利用する Docker ネットワークのID                                  | 可                            | 20230101                                                                                                |
| LOGGING_MAX_SIZE                        | コンテナ毎のログファイルの1ファイルあたりのファイルサイズ                   | 可                            | 10m                                                                                                     |
| LOGGING_MAX_FILE                        | コンテナ毎のログファイルの世代数                                            | 可                            | 10                                                                                                      |
| TZ                                      | Exastro システムで使用するタイムゾーン                                      | 可                            | Asia/Tokyo                                                                                              |
| DEFAULT_LANGUAGE                        | Exastro システムで使用する規定の言語                                        | 可                            | ja                                                                                                      |
| LANGUAGE                                | Exastro システムで使用する言語                                              | 可                            | en                                                                                                      |
| DB_VENDOR                               | 起動するデータベースコンテナ                                                | 可                            | **"mariadb"** (デフォルト): MariaDB を利用<br>**"mysql"**: MySQL を利用                                 |
| DB_VERSION                              | 起動するデータベースコンテナのバージョン                                    | 可                            | 10.11.4                                                                                                 |
| DB_PORT                                 | 起動するデータベースコンテナが公開するポート番号(TCP)                       | 可                            | 3306                                                                                                    |
| DB_ADMIN_USER                           | 起動するデータベースコンテナの管理ユーザー名                                | 可                            | root                                                                                                    |
| DB_ADMIN_PASSWORD                       | 起動するデータベースコンテナの管理ユーザーのパスワード                      | **必須**                      | Ch@ngeMeDBAdm                                                                                           |
| GITLAB_VERSION                          | 起動する Gitalb コンテナのバージョン                                        | 可                            | latest                                                                                                  |
| GITLAB_PROTOCOL                         | 起動する Gitalb コンテナの公開時のプロトコル                                | 可                            | http                                                                                                    |
| GITLAB_HOST                             | 起動する Gitalb コンテナの公開時のURL<br>AAPから接続できる必要がある。      | **必須**                      | gitlab                                                                                                  |
| GITLAB_PORT                             | 起動する Gitalb コンテナの公開時のポート番号                                | 可                            | 40080                                                                                                   |
| GITLAB_ROOT_PASSWORD                    | 起動する Gitalb コンテナの root アカウントの初期パスワード                  | **必須**                      | Ch@ngeMeGL                                                                                              |
| GITLAB_ROOT_TOKEN                       | 起動する Gitalb コンテナの root トークン                                    | **必須**                      | change-this-token                                                                                       |
| API_KEYCLOAK_HOST                       | Keycloak API エンドポイントのホスト名、もしくは、FQDN                       | 不要                          | keycloak                                                                                                |
| API_KEYCLOAK_PORT                       | Keycloak API エンドポイントのポート番号                                     | 不要                          | 8080                                                                                                    |
| API_KEYCLOAK_PROTOCOL                   | Keycloak エンドポイントのプロトコル                                         | 不要                          | http                                                                                                    |
| KEYCLOAK_HOST                           | Keycloak エンドポイントのホスト名、もしくは、FQDN                           | 不要                          | keycloak                                                                                                |
| KEYCLOAK_PORT                           | Keycloak API エンドポイントのポート番号                                     | 不要                          | 8080                                                                                                    |
| KEYCLOAK_PROTOCOL                       | Keycloak エンドポイントのプロトコル                                         | 不要                          | http                                                                                                    |
| KEYCLOAK_MASTER_REALM                   | Keycloak のマスターレルム名                                                 | 不要                          | Master                                                                                                  |
| SYSTEM_ADMIN                            | システム管理者のユーザ名                                                    | 不要                          | admin                                                                                                   |
| SYSTEM_ADMIN_PASSWORD                   | システム管理者のパスワード                                                  | **必須**                      | Ch@ngeMeKCAdm                                                                                           |
| KEYCLOAK_DB_VENDOR                      | Keycloak が利用するデータベースエンジン                                     | 可 (外部のデータベース利用時) | mariadb                                                                                                 |
| KEYCLOAK_DB_HOST                        | Keycloak が利用するデータベースのホスト名                                   | 可 (外部のデータベース利用時) | mariadb                                                                                                 |
| KEYCLOAK_DB_PORT                        | Keycloak が利用するデータベースのポート番号                                 | 可 (外部のデータベース利用時) | 3306                                                                                                    |
| KEYCLOAK_DB_USER                        | Keycloak が利用するデータベースのユーザ名                                   | 可 (外部のデータベース利用時) | keycloak                                                                                                |
| KEYCLOAK_DB_PASSWORD                    | Keycloak が利用するデータベースのパスワード                                 | **必須**                      | Ch@ngeMeKCADB                                                                                           |
| KEYCLOAK_DB_DATABASE                    | Keycloak が利用するデータベース名                                           | 可                            | keycloak                                                                                                |
| EXTERNAL_URL_PROTOCOL                   | Exastro Platform エンドポイントの公開プロトコル                             | 可                            | http                                                                                                    |
| EXTERNAL_URL_HOST                       | Exastro Platform エンドポイントの公開ホスト                                 | **必須**                      | 127.0.0.1                                                                                               |
| EXTERNAL_URL_PORT                       | Exastro Platform エンドポイントの公開ポート番号                             | 可                            | 80                                                                                                      |
| EXTERNAL_URL_MNG_PROTOCOL               | Exastro Platform 管理コンソールのエンドポイントの公開プロトコル             | 可                            | http                                                                                                    |
| EXTERNAL_URL_MNG_HOST                   | Exastro Platform 管理コンソールのエンドポイントの公開ホスト                 | **必須**                      | 127.0.0.1                                                                                               |
| EXTERNAL_URL_MNG_PORT                   | Exastro Platform 管理コンソールのエンドポイントの公開ポート番号             | 可                            | 81                                                                                                      |
| ENCRYPT_KEY                             | Exastro Platform 内で保管するデータの暗号化と復号のための AES キー          | **必須**                      | 'Q2hhbmdlTWUxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ='                                                          |
| PLATFORM_VERSION                        | Exastro Platform のバージョン                                               | 可                            | 1.5.1                                                                                                   |
| PLATFORM_DB_VENDOR                      | Exastro Platform が利用するデータベースエンジン                             | 可 (外部のデータベース利用時) | **"mariadb"** (デフォルト): MariaDB を利用<br>**"mysql"**: MySQL を利用                                 |
| PLATFORM_DB_HOST                        | Exastro Platform が利用するデータベースのホスト名                           | 可 (外部のデータベース利用時) | mariadb                                                                                                 |
| PLATFORM_DB_PORT                        | Exastro Platform が利用するデータベースのポート番号                         | 可 (外部のデータベース利用時) | 3306                                                                                                    |
| PLATFORM_DB_USER                        | Exastro Platform が利用するデータベースのユーザ名                           | 可 (外部のデータベース利用時) | app_user                                                                                                |
| PLATFORM_DB_PASSWORD                    | Exastro Platform が利用するデータベースのパスワード                         | **必須**                      | Ch@ngeMePFDB                                                                                            |
| PLATFORM_DB_ADMIN_USER                  | Exastro Platform が利用するデータベースの管理者ユーザ名                     | 可 (外部のデータベース利用時) | app_user                                                                                                |
| PLATFORM_DB_ADMIN_PASSWORD              | Exastro Platform が利用するデータベースの管理者パスワード                   | **必須**                      | Ch@ngeMeDBAdm                                                                                           |
| PLATFORM_DB_DATABASE                    | Exastro Platform が利用するデータベース名                                   | 可                            | platform                                                                                                |
| ITA_VERSION                             | Exastro IT Automation のバージョン                                          | 可                            | 2.1.2                                                                                                   |
| ITA_DB_VENDOR                           | Exastro IT Automation が利用するデータベースエンジン                        | 可 (外部のデータベース利用時) | **"mariadb"** (デフォルト): MariaDB を利用<br>**"mysql"**: MySQL を利用                                 |
| ITA_DB_HOST                             | Exastro IT Automation が利用するデータベースのホスト名                      | 可 (外部のデータベース利用時) | mariadb                                                                                                 |
| ITA_DB_PORT                             | Exastro IT Automation が利用するデータベースのポート番号                    | 可 (外部のデータベース利用時) | 3306                                                                                                    |
| ITA_DB_USER                             | Exastro IT Automation が利用するデータベースのユーザ名                      | 可 (外部のデータベース利用時) | ITA_USER                                                                                                |
| ITA_DB_PASSWORD                         | Exastro IT Automation が利用するデータベースのパスワード                    | **必須**                      | Ch@ngeMeITADB                                                                                           |
| ITA_DB_USER                             | Exastro IT Automation が利用するデータベースのユーザ名                      | 可 (外部のデータベース利用時) | ITA_USER                                                                                                |
| ITA_DB_PASSWORD                         | Exastro IT Automation が利用するデータベースのパスワード                    | **必須**                      | Ch@ngeMeDBAdm                                                                                           |
| ITA_DB_DATABASE                         | Exastro IT Automation が利用するデータベース名                              | 可                            | ITA_DB                                                                                                  |
| HOST_DOCKER_UID                         | Exastro IT Automation の実行ユーザ                                          | 不要                          | **1000**: Docker 利用の場合<br>**0**: Podman 利用の場合                                                 |
| HOST_DOCKER_GID                         | ホスト上の Docker のグループID                                              | 不要                          | **999**: Docker 利用の場合<br>**0**: Podman 利用の場合                                                  |
| HOST_DOCKER_SOCKET_PATH                 | ホストの Docker もしくは Podman のソケットファイルのパス                    | 可                            | **/var/run/docker.sock**: Docker 利用の場合<br>**/run/user/1000/podman/podman.sock**: Podman 利用の場合 |
| PWD                                     | Exastro IT Automation が利用する共有フォルダのパス                          | 可                            | カレントディレクトリー                                                                                  |
| ANSIBLE_AGENT_IMAGE                     | Ansible Agent のコンテナイメージのリポジトリ名                              | 不要                          | exastro/exastro-it-automation-by-ansible-agent                                                          |
| ANSIBLE_AGENT_IMAGE_TAG                 | Ansible Agent のコンテナイメージのタグ                                      | 不要                          | 2.1.2                                                                                                   |
| SYSTEM_ANSIBLE_EXECUTION_LIMIT          | Exastro システム全体の Movement 最大実行数                                  | 可                            | 25                                                                                                      |
| ORG_ANSIBLE_EXECUTION_LIMIT_DEFAULT     | Exastro システム全体の Movement デフォルト実行数                            | 可                            | 25                                                                                                      |
| ORG_ANSIBLE_EXECUTION_LIMIT_MAX         | オーガナイゼーションごとの Movement 最大実行数                              | 可                            | 1000                                                                                                    |
| ORG_ANSIBLE_EXECUTION_LIMIT_DESCRIPTION | Movement 最大実行数の説明文表記                                             | 不要                          | Maximum number of movement executions for organization default                                          |
