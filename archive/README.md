# Архив прежнего рабочего процесса

- [sql/parking/](sql/parking/) — SQL автостоянки, demo.sql, проверки и старые прогоны.
- Примеры sales сохранены в ноутбуках [ЛР2](../labs/lab02/lab2_sales_db.ipynb) и [ЛР3](../labs/lab03/lab3_sales_tables.ipynb); отдельного SQL-каталога сейчас нет.
- [logs/](logs/) — ранее полученные протоколы выполнения.
- [full_version/](full_version/) — расширенная версия РГР с EXCLUDE и индексами.
- [instructions/](instructions/) — прежние README для справки.

Рабочий процесс теперь описан в [основном README](../README.md).
Старые скрипты не запускались при реорганизации. `run_all.sh` пересоздаёт
базу parking; для обычной работы используйте ноутбуки.
PowerShell-прогон сохраняет логи в archive/logs/; Bash выводит протокол в терминал.

В обоих прогонах убран вызов отсутствовавшего `lab5_textbook_example.sql`.
Учебные примеры ЛР5 доступны в
[ноутбуке](../labs/lab05/lab5_textbook_example.ipynb).
