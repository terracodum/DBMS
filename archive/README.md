# Архив прежнего рабочего процесса

- [sql/parking/](sql/parking/) — SQL автостоянки, demo.sql, проверки и старые прогоны.
- Примеры sales доступны в [ЛР2](../labs/lab02/README.md) и [ЛР3](../labs/lab03/README.md): ноутбуки и актуальные SQL лежат рядом в labs/.
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
