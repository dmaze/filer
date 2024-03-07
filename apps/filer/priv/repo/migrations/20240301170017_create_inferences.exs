defmodule Filer.Repo.Migrations.CreateInferences do
  use Ecto.Migration

  def change do
    create table(:inferences) do
      add :value_id, references(:values, on_delete: :delete_all), null: false
      add :content_id, references(:contents, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:inferences, [:value_id])
    create index(:inferences, [:content_id])
  end
end
