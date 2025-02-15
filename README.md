### Описание

Простая реализация деплоя проекта из gitlab-репозитория для небольшой команды разработчиков (2-5 чел.) с уведомлениями в telegram.

На основе материалов из статьи: [Деплой (deploy) обычного сайта через Gitlab на примере Bitrix](https://serveradmin.ru/deploj-deploy-obychnogo-sajta-cherez-gitlab-na-primere-bitrix/) от serveradmin.ru.

Приняты следующие условия и допущения:
- на прод-среду нельзя/не хочется устанавливать gitlab-runner
- **master** - основная ветка проекта, соответствующая состоянию кода на прод-среде
- прямой push в master запрещен. Под каждую доработку создается отдельная ветка. Доработки вносятся посредством merge request, у каждого конкретного MR должен стоять хотя бы 1 approval. В противном случае скрипт деплоя выдаст ошибку
- все доработки ведутся в папке /local, изменения через "Эрмитаж" не вносятся

Возможно доработать/изменить условия, отредактировав скрипт */git/git.pull.sh* под себя.

#### Структура файлов

/git - папка с основным скриптом и логами (посмотреть вывод в консоли linux: *cat /home/bitrix/git/log_gitlab.txt* или *tail -100 /home/bitrix/git/log_gitlab.txt*)
	- git.pull.sh - основной скрипт
/tmp/autopull - временная директория для получения текущего состояния репозитория

/www - основная папка сайта, document root
/www/local/ - папка, где ведутся доработки по проекту
/www/gitpull/index.php - страница, к которой будет обращаться gitlab

#### Принцип работы и настройка

Настраиваем вебхук в gitlab на срабатывание по соответствующему событию (Push Events только для ветки master).

Настраиваем ключи в Access Tokens

Копируем файлы в соответствующие папки на сайте.

Вносим соответствующие значения переменных в файл /git/git.pull.sh (ваш сервер git, access token, apikey бота и т.д.)

```
// file: /www/gitpull/index.php
$token = "<your-webhook-token>";
__________________________________________________________________

// file: /git/git.pull.sh
# Variables

REPO_URL="http://<git-access-token>:@<url-to-your-repo>" # Git repo URL

CLONE_DIR="/home/bitrix/tmp/autopull" # clone directory

SYNC_DIR="/home/bitrix/www/" # sync directory

LOG_FILE="/home/bitrix/git/log_git.txt" # Log file path

  

BACKUP_DIR="$CLONE_DIR/log_backup" # Backup directory for SYNC_DIR/log

GITLAB_API_URL="https://<your-gitlab-url>" # Gitlab API URL

PROJECT_ID="<your-project-id>" # GitLab project ID

PRIVATE_TOKEN="<your-token-here>" # GitLab private token

...

# Function to send telegram alerts

send_telegram_alert() {

	local BOT_TOKEN="<your-telegram-bot-token-here>"
	
	local CHAT_ID="telegram-chat-id"
	...
}
```

При срабатывании события push в ветку master будет срабатывать вебхук для запуска основного скрипта. 
Основной скрипт скачивает текущее состояние вашего указанного репозитория и синхронизирует папки /local/ из временной папки с папкой на сайте.
В telegram присылаются уведомления о запуске скрипта (произошло слияние ветки задачи и master),  автор, название коммита, успех/неуспех операции.

Логи по умолчанию записываются в /git/log_gitlab.txt

