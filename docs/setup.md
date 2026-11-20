# Установка и запуск

## PostgreSQL под Windows

Установи PostgreSQL и убедись, что служба запущена. WSL и Docker не нужны.
Открой PowerShell в корне репозитория. Если psql отсутствует в PATH,
добавь каталог bin для текущего сеанса:

```powershell
$env:Path = "C:\Program Files\PostgreSQL\18\bin;" + $env:Path
psql --version
```

Один раз подключись под администратором:

```powershell
psql -h localhost -U postgres -d postgres
```

В psql создай пользователя и базу. Уже существующие объекты создавать не нужно:

```sql
CREATE ROLE warehouse_user LOGIN;
\password warehouse_user
CREATE DATABASE fulfillment_warehouse OWNER warehouse_user;
\q
```

Пароль задается через приглашение и не попадает в историю команд.
Затем выполни установку:

```powershell
psql -h localhost -U warehouse_user -d fulfillment_warehouse -f scripts/install.sql
```

Установщик применяет каждую миграцию в отдельной транзакции и останавливается
при ошибке. Если схема warehouse уже существует, он отказывается работать.
При сбое новой установки устрани причину и примени оставшиеся миграции вручную
либо используй другую пустую базу. Таблицы учета примененных миграций
и автоматического отката версии схемы в проекте нет.

## Работа в VS Code

Подключись к localhost:5432, базе fulfillment_warehouse,
под пользователем warehouse_user. Включи автоподтверждение и выполняй файлы целиком.
scripts/install.sql и scripts/test.sql содержат команды psql:
их нужно запускать из терминала. Отдельные файлы из sql/ и tests/
содержат обычный SQL и могут выполняться в редакторе.

Некоторые тесты содержат BEGIN и ROLLBACK. Запускай их в отдельном подключении
после подтверждения сгенерированных данных. ROLLBACK также откатывает
все ранее неподтвержденные изменения в том же подключении.
Если редактор сообщает о прерванной транзакции, сначала выполни ROLLBACK.

Если расширение само открывает транзакции, запускай тесты через psql.
Предупреждение об уже открытой транзакции на BEGIN означает, что скрипт
присоединился к ней, а не создал вложенную транзакцию.

## Если база уже установлена

Если миграции 01-08 и 11 уже выполнены, обновлять схему для этой версии не нужно.
Добавлены документация, форматирование, скрипты запуска и пример.
Повторно выполнять старые CREATE TABLE и CREATE TYPE в заполненной базе нельзя.

Если применены только миграции 01-05, последовательно выполни 06, 07, 08 и 11.
Файлы 09 и 10 можно повторять после генерации данных.

## Данные и тесты

```powershell
psql -h localhost -U warehouse_user -d fulfillment_warehouse -c "CALL warehouse.generate_demo_data(5000, 0.42);"
psql -h localhost -U warehouse_user -d fulfillment_warehouse -f scripts/test.sql
```

Успешный отдельный CALL подтверждает данные до начала тестов.
Генератор при каждом вызове добавляет записи. Проверить один завершенный запуск:

```sql
SELECT count(*) FROM warehouse.receipts;        -- 5500
SELECT count(*) FROM warehouse.shipments;       -- 5000
SELECT count(*) FROM warehouse.stock_movements; -- 20500
SELECT * FROM warehouse.v_inventory_reconciliation; -- результат должен быть пустым
```

Эти количества предполагают, что до генерации в базе не было рабочих данных.

## Запуск через Python

Python необязателен. Для скрипта генерации и интеграционных проверок:

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r python/requirements.txt
$env:DATABASE_URL = "postgresql://warehouse_user@localhost:5432/fulfillment_warehouse"
.venv\Scripts\python.exe python/generate_data.py --cycles 5000 --seed 0.42
```

Настрой локальный файл паролей PostgreSQL либо передай учетные данные
через окружение. Не сохраняй строки подключения с паролями в репозитории.
Спецсимволы в пароле внутри URI нужно записывать с процентным кодированием.

Автоматический скрипт сам устанавливает схему, поэтому ему нужна другая пустая база:

```powershell
createdb -h localhost -U warehouse_user warehouse_test
$env:TEST_DATABASE_URL = "postgresql://warehouse_user@localhost:5432/warehouse_test"
.venv\Scripts\python.exe tests/run_integration.py
```

Создание базы требует права CREATEDB. Если его нет, попроси администратора
создать warehouse_test с владельцем warehouse_user. Скрипт отказывается
запускаться, если схема warehouse уже существует. Он подтверждает
небольшой сгенерированный набор и оставляет тестовую базу доступной для изучения.
