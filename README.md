# Filer

This is a toy-quality project for analyzing and categorizing the large quantity of PDF files that come out of my home scanner.  It is inspired by the scanner software's inability to automatically categorize scans, and the poor quality of its OCR.

There are two main goals of this:

1. Do automatic binary classification to match a PDF to a limited-cardinality set of tags (probably easy);
2. Automatically extract metadata like dates and amounts in context (probably hard).

As of this writing this is in a usable state for the binary-classification problem, and it's unlikely to progress to anything near production-quality.

## Workflow

The application consists of two major parts.  The filer application itself includes the Web UI, content storage, and machine learning parts; these can be run separately if needed.  There is a separate scanner application that uploads local files into the application.

A typical workflow will be to:

1. Start the main application, with a separate data store
2. Start the scanner, pointing at local files
3. In the application, define labels and label documents
4. In the application, invoke the ML training step
5. Search for documents
6. Refine labels and retrain

## Building and Running

Note that the Docker-based paths take a while to bring up.  The `Dockerfile` tries to make effective use of Docker layer caching, but even so, changes to any of the `mix.exs` files or the build-time `config.exs` or `prod.exs` configuration results in a full rebuild of dependencies.  A full dependency rebuild takes about 5 minutes on the author's system; building the Web application an additional full minute.

### Docker Single Node

Edit the `.env` file.  Set good-quality random values for `POSTGRES_PASSWORD`, `RELEASE_COOKIE`, and `SECRET_KEY_BASE`.  For example,

```sh
dd if=/dev/urandom bs=48 count=1 | base64
```

Also set `FILER_HOST_NAME` to a host name that will be externally reachable once the container is running.  If you are using Docker on native Linux or Docker Desktop on any platform, this will generally be `localhost`; if you are using Minikube then it will be the `minikube ip` address.

Build the Docker images for the application.

```sh
docker compose --profile unified build
```

Start the database and run migrations.

```sh
docker compose --profile unified run filer migrate
```

Then start the application.

```sh
docker compose --profile unified up -d
```

The application will be accessible on `http://localhost:4000/`.

Follow the instructions in "Scanning Local Files" below to load content into the system.

### Docker Distributed

This splits the application into three separate containers: one running the UI, one running background tasks such as PDF rendering and machine learning, and one running dedicated content storage.

Follow all of the same instructions as in "Docker Single Node" above, except use a `docker compose --profile distributed` option, and run the migrations specifically via the Web container.

Note that the compilation process can be fairly memory-hungry, particularly for the Web application, and you may need to separately build it.

```sh
docker compose --profile distributed build web
docker compose --profile distributed build
docker compose --profile distributed run web migrate
docker compose --profile distributed up -d
```

### Docker on Minikube

If you are using Minikube as your Docker environment, there are a couple of important considerations.

The compilation process is fairly memory-hungry.  Some amount of the VM's memory gets consumed by the Kubernetes processes, but even so, it is very possible to run into memory issues building the application.  In practice you may need to set

```sh
minikube config set memory 8g
minikube delete
minikube start
eval $(minikube docker-env)
```

The Minikube VM has its own IP address, and unlike Docker Desktop it does not automatically route ports from the host system.  Running

```sh
minikube ip
```

will print out the VM's IP address.  You will need to use this address:

* In `.env`, as the `FILER_HOST_NAME`
* In your browser, when you connect to the application
* As the `FILER_URL` when you run the local scanner below

### Local Single Node

Build the application and scanner using the Elixir `mix` build tool

```sh
MIX_ENV=prod mix release filer
(cd filer_scanner && MIX_ENV=prod mix release)
```

Create a PostgreSQL database using your choice of tooling.  Set an environment variable `DATABASE_URL` pointing at it.

```sh
export DATABASE_URL=ecto://username:passw0rd@hostname/dbname

# Using the Minikube/Docker setup described below:
export DATABASE_URL=ecto://postgres:passw0rd@$(minikube ip)/filer_dev
```

Set an environment variable `SECRET_KEY_BASE` to a random value.

```sh
export SECRET_KEY_BASE=$(dd if=/dev/random bs=30 count=1 | base64)
```

Create a directory to store persistent files and set an environment variable `FILER_STORE` pointing at it.

```sh
mkdir store
export FILER_STORE="$PWD/store"
```

Start the application.

```sh
_build/prod/rel/filer/bin/filer start
```

The application will be accessible on `http://localhost:4000/`.

Follow the instructions in "Scanning Local Files" below to load content into the system.

### Scanning Local Files

This applies to all paths above.

Set an environment variable `FILER_PATH` pointing at your local data files, and run the scanner as well.  The scanner by default will exit as soon as all of the local files have been read in, though this could take a couple of minutes depending on the size of your local data.

```sh
export FILER_PATH=$HOME/Documents/pdf_files
export FILER_URL=http://localhost:4000
cd filer_scanner
mix start --no-halt
```

### Developer Setup

In this directory, create an empty directory named `store` to hold binary artifacts, like prerendered PNG files.

Also in this directory, create a symbolic link named `data` to the root of the directory tree that contains the PDF files.  An alternate path can be configured in `config/runtime.exs`.

Start a PostgreSQL database.  In `config/dev.exs`, change the `config :filer, Filer.Repo` settings to have the database credentials.

If you don't immediately have a database running, but you do have Docker, running `docker-compose up -d db` will get you a database in a container.  On a native-Linux system or using Docker Desktop, change the database configuration to reference `localhost`.  Using Minikube as your Docker environment, use the `minikube ip` address as the database location.

In the top-level directory, run

```sh
mix ecto.migrate
mix phx.server
```

The application will be accesible on `http://localhost:4000`.
