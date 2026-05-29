# DevOps Lab 4: Terraform + Ansible

Розгортання веб-застосунку Task Tracker на двох віртуальних машинах за допомогою Terraform (provisioning) та Ansible (configuration management).

## Варіант індивідуального завдання

Порядковий номер у списку групи (N): **13**

| Параметр | Формула | Результат |
|----------|---------|-----------|
| V2 (БД та конфігурація) | (13 % 2) + 1 = 2 | PostgreSQL, конфіг `/etc/mywebapp/config.json` |
| V3 (Тематика) | (13 % 3) + 1 = 2 | Task Tracker |
| V5 (Порт) | (13 % 5) + 1 = 4 | 8000 |

## Архітектура

```
                 +---------- VM1 (worker) -----------+    +--- VM2 (db) ---+
client  →  | nginx (0.0.0.0:80) → app (127.0.0.1:8000) | → | PostgreSQL:5432 |
                 +---------------------------------------+    +----------------+
```

| Компонент  | Адреса      | Порт |
|-----------|-------------|------|
| nginx     | 0.0.0.0     | 80   |
| web app   | 127.0.0.1   | 8000 |
| PostgreSQL| VM2 IP      | 5432 |

## Структура проєкту

```
.
├── app.js, routes.js, db.js, migrate.js   # Код застосунку
├── config.json                            # Конфіг для локальної розробки
├── package.json
├── Dockerfile, docker-compose.yml         # Docker (Лаб. 2)
├── deploy/                                # Systemd та Nginx конфіги
├── terraform/                             # Інфраструктура
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── cloud-init/
│       ├── worker.yml
│       └── db.yml
└── ansible/                               # Конфігурація
    ├── ansible.cfg
    ├── inventory.ini
    ├── playbook.yml
    └── roles/
        ├── common/                        # Користувач teacher
        ├── db/                            # PostgreSQL
        ├── webapp/                        # Node.js + systemd
        └── nginx/                         # Reverse proxy
```

## Передумови

На **хост-машині** (Linux з підтримкою KVM) потрібно:

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system virtinst bridge-utils
sudo apt install -y terraform ansible
ansible-galaxy collection install community.postgresql community.general
```

Завантажити Ubuntu Cloud Image:

```bash
# Для ARM64 (Apple Silicon Mac + UTM):
sudo wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-arm64.img \
  -O /var/lib/libvirt/images/ubuntu-22.04-server-cloudimg-arm64.img

# Для AMD64 (звичайний x86_64 Linux):
# sudo wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img \
#   -O /var/lib/libvirt/images/ubuntu-22.04-server-cloudimg-amd64.img
```

Згенерувати SSH-ключ (якщо ще немає):

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

> **Примітка:** Цей проєкт розроблявся на Apple Silicon Mac з UTM (ARM64 nested KVM).
> Terraform конфігурація (`main.tf`) налаштована для архітектури `aarch64`.
> Для запуску на x86_64 хості потрібно змінити в `terraform/main.tf`:
> - `type_arch` з `"aarch64"` на `"x86_64"`
> - `type_machine` з `"virt"` на `"pc"`
> - Видалити блок `firmware_info` (secure-boot налаштування специфічне для ARM64 EFI)
> - Змінити `firmware` з `"efi"` на потрібний, або видалити цей рядок

## Етап 1: Terraform — створення ВМ

```bash
cd terraform
terraform init
terraform apply -var "ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
```

Після успішного виконання Terraform виведе IP-адреси обох ВМ:

```
worker_ip = "192.168.100.X"
db_ip = "192.168.100.Y"
```

## Етап 2: Ansible — налаштування ВМ

Оновити IP-адреси в `ansible/inventory.ini`:

```ini
[workers]
worker ansible_host=192.168.100.X

[db]
db ansible_host=192.168.100.Y
```

Запустити playbook:

```bash
cd ansible
ansible-playbook playbook.yml
```

## Користувачі

| Користувач | ВМ | Призначення | Пароль/Доступ |
|-----------|-----|-------------|---------------|
| ansible | Усі | Автоматичне налаштування | SSH-ключ, sudo без пароля |
| teacher | Усі | Перевірка роботи | 12345678, sudo з паролем |
| app | worker | Запуск застосунку | Системний користувач |
| operator | worker | Керування сервісами | 12345678, обмежений sudo |
| student | worker | Gradebook | — |

Operator може виконувати тільки:
- `sudo systemctl start/stop/restart/status mywebapp.service`
- `sudo systemctl reload nginx`

## API-ендпоінти

| Метод | Шлях | Опис |
|-------|------|------|
| GET | `/` | Головна сторінка зі списком ендпоінтів |
| GET | `/tasks` | Список усіх задач |
| POST | `/tasks` | Створити задачу (body: `{"title": "..."}`) |
| POST | `/tasks/:id/done` | Відмітити задачу як виконану |
| GET | `/health/alive` | Перевірка стану застосунку |
| GET | `/health/ready` | Перевірка підключення до БД |

## Перевірка роботи

Після виконання Ansible перевірте:

```bash
# Health check — застосунок живий
curl http://WORKER_IP/health/alive

# Health check — зв'язок з БД
curl http://WORKER_IP/health/ready

# Створити задачу
curl -X POST http://WORKER_IP/tasks -H "Content-Type: application/json" -d '{"title": "Test task"}'

# Переглянути задачі
curl http://WORKER_IP/tasks

# Перевірити gradebook
ssh teacher@WORKER_IP "cat /home/student/gradebook"

# Перевірити operator permissions
ssh operator@WORKER_IP "sudo systemctl status mywebapp.service"

# Перевірити що БД недоступна ззовні
curl http://DB_IP:5432  # має бути відмовлено
```

## Локальна розробка

```bash
npm install
node migrate.js
node app.js
```

Застосунок буде доступний на `http://localhost:8000`.

## Docker Compose (Лаб. 2)

```bash
docker-compose up -d
```

Запускає PostgreSQL, Node.js App та Nginx в контейнерах.