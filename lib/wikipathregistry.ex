defmodule WikipathRegistry do
	def start_link do
		shortest_route_length = 10000
		Task.start_link(fn -> loop(shortest_route_length, "", [], []) end)
	end
	
	defp check_alive(workers) do
		workers |> Enum.filter(&Process.alive?/1)
	end

	defp loop(shortest_route_length, path, subscribers, workers) do
		active_workers = check_alive(workers)
		active_length = length active_workers
		if ((active_length == 0) && (shortest_route_length < 10000)) do
			subscribers
			|> Enum.map(&(send &1, {:minimal_length_found, shortest_route_length, path}))
		end

		receive do
			{:request_execution, function} ->
				pid = spawn fn -> function.() end
				Process.monitor(pid)
				loop(shortest_route_length, path, subscribers, active_workers ++[pid])
			{:subscribe, caller} ->
				loop(shortest_route_length, path, subscribers ++ [caller], active_workers)
			{:get, caller} ->
				send caller, shortest_route_length
				loop(shortest_route_length, path, subscribers, active_workers)
			{:put, _, value, new_path} ->
				subscribers
				|> Enum.map(&(send &1, {:new_length_found, value}))
 
				if value < shortest_route_length do
					loop(value, new_path, subscribers, active_workers)
				else
					loop(shortest_route_length, path, subscribers, active_workers)
				end
			{:DOWN, _, :process, _, _} ->
				loop(shortest_route_length, path, subscribers, active_workers)
		end
	end
end

