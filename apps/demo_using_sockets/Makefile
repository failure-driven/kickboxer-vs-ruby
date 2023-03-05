.DEFAULT_GOAL := demo

.PHONY: demo
demo:
	tmux -L "demo" new-session -d "bundle exec ruby udp_server.rb 4444"
	tmux -L "demo" split-window -t "0:0" -h "bundle exec ruby udp_client.rb 4444"
	tmux -L "demo" split-window -t "0:0" -h "bundle exec ruby udp_device.rb 4444 4445"
	tmux -L "demo" select-layout -t "0:0" even-horizontal
	tmux -L "demo" -CC attach-session

.PHONY: demo-attach
demo-attach:
	tmux -L "demo" -CC attach-session

.PHONY: demo-down
demo-down:
	tmux -L "demo" kill-session

