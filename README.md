# Скрипт для установки связки прокси для Binance

Этот проект был создан для упрощения настройки цепочки прокси-серверов для использования с Binance.
Репозиторий содержит два скрипта, предназначенных для установки на конечный и промежуточный серверы.

## Содержание

- `ss.sh` - Скрипт для установки на конечный сервер.
- `dc.sh` - Скрипт для установки на промежуточный сервер.

## Установка


                         +--------------------------------------+      +--------------------------------------------+             +-------------------+      
                         |         Клиент Shadowsocks           |      |           Промежуточный сервер             |             |   Конечный сервер |      
+----------------+       |                                      |      |               (Хабаровск)                  |             |       (Токио)     |      +--------------------+
|   Терминал     |       | IP 127.0.0.1       IP XXX.XXX.XXX.XXX|      | IP XXX.XXX.XXX.XXX       IP EEE.EEE.EEE.EEE|             | IP EEE.EEE.EEE.EEE|      |                    |
| IP 127.0.0.1   | <-->  | Порт 1080                   Порт XXXX| <--> | Порт XXXX                         Порт XXXX| <-->... <-->| Порт XXXX         | <--> |    Cервер биржи    |
| Порт 1080      |       |                         Пароль NNNNNN|      | Пароль NNNNNN                 Пароль NNNNNN|             | Пароль NNNNNN     |      |                    |
+----------------+       |                                      |      |                                            |             |                   |      +--------------------+
                         +--------------------------------------+      +--------------------------------------------+             +-------------------+
                                                                                

### Конечный сервер

Для установки на конечный сервер, выполните следующие команды:

```bash
wget https://raw.githubusercontent.com/Sclpr/proxy_chain/main/ss.sh -O ss.sh && bash ss.sh
```

При запуске скрипт запросит ввод порта и пароля. Если оставить поля пустыми, будут использоваться значения по умолчанию.

###  Промежуточный сервер
Для установки на промежуточный сервер, выполните следующие команды:

```bash
wget https://raw.githubusercontent.com/Sclpr/proxy_chain/main/dc.sh -O dc.sh && bash dc.sh
```

При запуске скрипт запросит ввод входящего порта, пароля (состоящего только из цифр), IP-адреса следующего сервера в цепочке (либо конечного) и исходящего порта.


## Рекомендуемые сервисы для аренды серверов

- [ShockHosting](https://shockhosting.com/portal/aff.php?aff=1184) - Токио. В данный момент вручную нельзя выбрать Токио, но есть возможность взять через техподдержку при условии оплаты сразу за год.
- [Vultr](https://www.vultr.com/?ref=9635843) - Токио.
- [WebHorizon](https://clients.webhorizon.net/?affid=93) - Токио. Подходящий вариант для Binance доступен только на тарифе за 9$. Перед оформлением нужно написать в техподдержку на сайте, предупредить что нужен сервер именно для Binance. Простая оплата в USDT.
- [EdgeCenter](https://edgecenter.ru/hosting/price/vds?from=14840289) - Хабаровск.
