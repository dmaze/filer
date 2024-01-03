# Filer

This is a toy-quality project for analyzing and categorizing the large quantity of PDF files that come out of my home scanner.  It is inspired by the scanner software's inability to automatically categorize scans, and the poor quality of its OCR.

There are two main goals of this:

1. Do automatic binary classification to match a PDF to a limited-cardinality set of tags (probably easy);
2. Automatically extract metadata like dates and amounts in context (probably hard).

As of this writing this is in a very early state, and it's unlikely to progress to anything near production-quality.

## Developer Setup

Edit `config/runtime.exs`.  In the setting

```elixir
config :filer_index, root_dir: "..."
```

put the root of the directory tree that contains the PDF files.

Start a PostgreSQL database.  In `config/dev.exs`, change the `config :filer, Filer.Repo` settings to have the database credentials.

If you don't immediately have a database running, but you do have Docker, running `docker-compose up -d db` will get you a database in a container.  On a native-Linux system or using Docker Desktop, change the database configuration to reference `localhost`.  Using Minikube as your Docker environment, use the `minikube ip` address as the database location.

In the top-level directory, run

```sh
mix ecto.migrate
mix phx.server
```

The application will be accesible on `http://localhost:4000`.
