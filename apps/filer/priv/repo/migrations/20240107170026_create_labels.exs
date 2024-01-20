defmodule Filer.Repo.Migrations.CreateLabels do
  use Ecto.Migration

  def change do
    create table(:labels) do
      add :value, references(:values, on_delete: :delete_all), null: false
      add :content, references(:contents, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:labels, [:value])
    create index(:labels, [:content])
  end
end
