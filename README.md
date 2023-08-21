# Exastro IT Automation in Docker Compose  
このdocker-composeは、Dockerを使用し Exastro IT Automation を起動して実行できるようにします。  
  - (based on [exastro-it-automation](https://github.com/exastro-suite/exastro-it-automation))  
  - (based on [exastro-platform](https://github.com/exastro-suite/exastro-platform))  
  

## 使用法  
Exastro IT Automation の起動には、**profile** によって起動するコンテナを指定することで、環境ごとに起動するコンテナを選択することが可能です。  
  

### common-services の docker-compose up  
はじめに、各種構成ファイルを取得します。

```
git clone https://github.com/exastro-suite/exastro-docker-compose.git
```

exastro-docker-compose ディレクトリでコンテナを起動します。  
この例では、**all** プロファイルを指定することで、すべてのコンテナを一度に起動します。

```shell
cd exastro-docker-compose

# 以下のコマンドの出力結果を .envファイルのENCRYPT_KEYに設定してください。
head -c 32 /dev/urandom | base64

cp .env.sample .env  # 値を変更することなく起動が可能ですが、変更を行いたい場合は .envファイルを編集してください。  

# --waitオプションを指定し Gitlabの起動を待ちます。 Gitlabの起動には、10分程掛かる場合があります。  
docker-compose --profile all up -d  
```  


### Organization作成  
exastro-platform/toolsディレクトリに、Organization作成用のスクリプトがあります。  
このスクリプトを使用し、Organization作成が実行できます。  
  
※ スクリプトの詳細は、以下を参照してください。  
https://ita-docs.exastro.org/2.1/ja/manuals/platform_management/organization.html  
  
```shell
cd ../exastro-platform/tools
./create-organization.sh
```
  

### 各サイトURL  
システム管理者用コンソール  
http://EXTERNAL_URL:38001/auth/  
  
作成したOrganizationの管理ページ  
http://EXTERNAL_URL:38000/{オーガナイゼーションID}/platform/  
  
Gitlab  
http://EXTERNAL_URL:40080/  
  
※docker-composeで、各ポートの設定を変更した場合は、変更後のポートで各サイトにアクセスしてください。  
  
  