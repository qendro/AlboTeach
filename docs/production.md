# Production deployment

The Northflank project `alboteach` replaces the former `habbits` project. Its combined service `alboteach-web` builds `https://github.com/qendro/AlboTeach` from `main` using `/albo/Dockerfile` with `/albo` as the build context. The linked GitHub account is `qendro`. Continuous integration and continuous deployment are enabled: pushes to `main` build and deploy automatically.

Both `habbits.xyz` and `www.habbits.xyz` route to the service's HTTP port 4000. `/health` is the readiness check. The runtime configuration sets `PHX_HOST=habbits.xyz`, enables the Phoenix server, and permits the www and current Northflank code.run origins.

## Persistent data

The service runs one instance with the recreate deployment strategy. The 6 GiB `alboteach-data` volume is mounted at `/data`, with SQLite at `/data/albo.sqlite`. Builds contain web and print pictures, their licenses, and collection exports; the database remains on the volume across deployments. Startup applies schema migrations without inserting content. Starter cards can be loaded explicitly with `Albo.Learning.seed()`; intentionally empty collections stay empty after restarts.

The initial production collection was transferred from the verified local SQLite backup containing the reviewed 193 cards, preserving card IDs, content revisions, learner progress, practice history, quality feedback, and print counts. A vocabulary import alone does not preserve all of that history.

Future GitHub pushes update application code and bundled pictures. They do not overwrite or synchronize production card records with a local database. Edit production cards directly, use the duplicate-safe collection importer for additions, or perform a deliberate backed-up database transfer for a full replacement.

## Credentials and backups

Deployment management reads `NORTHFLANK_API_TOKEN` from the ignored local `albo/.env`. This credential is not included in the production service environment or committed to Git. Runtime environment values are configured separately in Northflank.

Before the old project was removed, its production SQLite database, service configuration, and legacy PostgreSQL dump were saved under the ignored local `backups/` directory. Keep these files private. The former PostgreSQL add-on is not needed by AlboTeach.

Use SQLite's online backup API when the service is running, verify integrity and foreign keys, and download a private copy before replacing data or deleting storage. The local `scripts/backup.sh` only backs up the local Docker collection; it does not contact Northflank.
