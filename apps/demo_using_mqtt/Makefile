.DEFAULT_GOAL := demo

.PHONY: brew-install
brew-install:
	brew bundle

.PHONY: install
install: brew-install

.PHONY: colima-start
colima-start:
	# colima start seems to have an invalid networkDriver error in conifg?
	colima list | grep Running || colima restart

.PHONY: demo
demo: colima-start
	tmux -L "demo" new-session -d "docker-compose up"
	sleep 5
	tmux -L "demo" split-window -t "0:0" -h "bundle exec ruby client.rb"
	tmux -L "demo" split-window -t "0:0" -h "bundle exec ruby actuator.rb"
	tmux -L "demo" split-window -t "0:0" -h "bundle exec ruby actuator.rb"
	tmux -L "demo" select-layout -t "0:0" even-horizontal
	tmux -L "demo" -CC attach-session

.PHONY: demo-attach
demo-attach:
	tmux -L "demo" -CC attach-session

.PHONY: demo-down
demo-down:
	tmux -L "demo" kill-session

