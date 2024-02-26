defmodule FilerIndex.Trainer do
  @moduledoc """
  Train ML models and keep a current model.

  """
  use Agent

  @doc """
  Start the trainer as a supervised process.

  Must pass `task_supervisor` as a keyword argument.

  """
  def start_link(opts) do
    {task_supervisor, opts} = Keyword.pop!(opts, :task_supervisor)
    Agent.start_link(fn -> %{ml: nil, training: false, task_supervisor: task_supervisor} end, opts)
  end

  @doc """
  Start training.

  Does nothing if training is already running.  Training takes a while, so
  runs it as a background task.

  """
  def train(trainer) do
    Agent.update(trainer, &start_training(trainer, &1))
  end

  defp start_training(_, %{training: true} = state) do
    state
  end

  defp start_training(trainer, %{task_supervisor: task_supervisor} = state) do
    Task.Supervisor.async_nolink(task_supervisor, __MODULE__, :do_training, [trainer])
    %{state | training: true}
  end

  @doc """
  Actually do training.

  This is intended to be run in a task; it is not intended to be called
  externally.

  """
  def do_training(trainer) do
    ml = FilerIndex.Ml.train()
    Agent.update(trainer, fn state -> %{state | ml: ml, training: false} end)
  end

  @doc """
  Query if a training task is running.

  """
  def training?(trainer) do
    Agent.get(trainer, & &1.training)
  end

  @doc """
  Forget that a training task is running.

  If one is running, this does not forcibly kill it.  It just makes it
  possible to call `train/1` again to get a new training job.

  """
  def force_stop_training(trainer) do
    Agent.update(trainer, fn state -> %{state | training: false} end)
  end

  @doc """
  Score some unit of content.

  Returns a set of values from the most recently completed training run.
  Returns an empty list if training has never run.

  """
  def score(trainer, content) do
    case Agent.get(trainer, & &1.ml) do
      nil -> []
      ml -> FilerIndex.Ml.score(content, ml)
    end
  end
end
