defmodule WikipathSync do
	def start_link do
		HTTPoison.start
		Task.start_link(fn -> loop() end)
	end
	defp loop() do
		receive do
			{:request_page, caller, url} ->
				response = HTTPoison.get! url
				send caller, {:page, response.body}
				:timer.sleep(10)
				loop()
		end
	end
end
