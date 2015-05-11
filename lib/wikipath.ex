defmodule Wikipath do
	# Entry point
	def start do
		[start_term, end_term] = System.argv
		# Defining the start URL
		start_url = "https://ru.wikipedia.org/wiki/" <> start_term
		
		# Starting the registry
		{:ok, pid} = WikipathRegistry.start_link
		
		# Creating the alias for the registry
		Process.register(pid, :registry)
		
		# Starting the web pages receiver
		{:ok, sync_pid} = WikipathSync.start_link
		
		# Creating the alias for the page receiver
		Process.register(sync_pid, :sync)
		
		# Subscription on the registry events
		send :registry, {:subscribe, self()}
		
		# Starting work
		start_page_process(start_url, end_term, 1, [start_term])
		wait_until_done
	end
	
	def wait_until_done do
		receive do
			# New short path found, resuming
			{:new_length_found, new_length} ->
				IO.puts "output > New length #{new_length}"
				wait_until_done
			
			# Shortest path found. Halting
			{:minimal_length_found, new_length, path} →
				IO.puts "output > Minimal length is #{new_length}, path is #{path}"
		end
	end
	
	def get_current_shortest_route_length do
		send :registry, {:get, self()}
		receive do
			length ->
				length
		end
	end
	
	def start_page_process(url, end_term, current_step_number, current_path) do
		# Sending the request to get web page
		send :sync, {:request_page, self(), url}
		
		# Receiving the result
		receive do
			{:page, body} ->
				body = body
		end
		
		# Finding all the internal hrefs in the page
		hrefs = Floki.find(body, "a")
		|> Floki.attribute("href")
		|> Enum.filter(&(&1 =~ ~r/^\/wiki/))
		|> Enum.map(&(String.replace &1, "/wiki/", ""))
		
		is_final_page = hrefs
		|> Enum.find(&(&1 == end_term))
		
		current_shortest_route = get_current_shortest_route_length
		if (is_final_page) do
			# This is final page, sending new result and halting
			send :registry, {:put, self(), current_step_number, current_path}
		else
			# Otherwise, starting new processes for each href
			if (current_step_number < current_shortest_route) do
				hrefs
				|> Enum.map(fn(url) ->
					unless current_path |> Enum.find(&(&1 == url)) do
						send :registry,
						{:request_execution, fn ->
							start_page_process(
								"https://ru.wikipedia.org/wiki/" <> URI.encode(url),
								end_term,
								current_step_number + 1,
								current_path ++ [URI.decode url]
							)
						end}
					end
				end)
			else
				IO.puts "Shorter route found. Halting"
			end
		end
	end
end
