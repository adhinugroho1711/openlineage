# OpenLineage Integration Project

This project demonstrates the integration of OpenLineage with Apache Airflow, MinIO, and MySQL for data lineage tracking.

## Project Structure
```bash
.
├── README.md
├── config/
│   ├── airflow_config.yaml
│   └── marquez_config.yaml
├── dags/
│   └── minio_to_mysql_dag.py
└── scripts/
    ├── install.sh
    ├── setup_mysql.sh
    ├── setup_minio.sh
    ├── setup_marquez.sh
    ├── setup_airflow.sh
    ├── generate_data.py
    └── utils.sh
```

## Requirements
- Ubuntu 22.04 LTS
- RAM: 3GB
- CPU: 2 cores
- Disk: 10GB

## Quick Start
1. Clone this repository
```bash
git clone https://github.com/adhinugroho1711/openlineage.git
cd openlineage
```

2. Run installation
```bash
./scripts/install.sh
```

3. Start services
```bash
./scripts/install.sh start
```

4. Generate sample data
```bash
./scripts/install.sh generate-data
```

## Access Points
- Airflow UI: http://localhost:8080 (admin/admin)
- MinIO Console: http://localhost:9001 (minioadmin/minioadmin)
- Marquez UI: http://localhost:3000

## License
MIT License
