package main

import (
	"flag"
	"io"
	"os"
	"os/exec"
	"strings"

	"github.com/cloudogu/sonarcarp/config"
	"github.com/cloudogu/sonarcarp/proxy"
	"github.com/op/go-logging"
)

var (
	// Version of the application
	Version = "x.y.z-dev"
	log     = logging.MustGetLogger("sonarcarp")
)

func startPayloadInBackground(configuration config.Configuration) {
	log.Infof("Start payload application in background..")
	log.Debugf("Execute command '%s'", configuration.ApplicationExecCommand)
	splitted := strings.Split(configuration.ApplicationExecCommand, " ")
	cmd := exec.Command(splitted[0], splitted[1:]...)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Fatalf("failed to get stdout pipeline: %s", err.Error())
		os.Exit(1)
	}

	stderr, err := cmd.StderrPipe()
	if err != nil {
		log.Fatalf("failed to get stderr pipeline: %s", err.Error())
		os.Exit(1)
	}

	if err := cmd.Start(); err != nil {
		log.Fatalf("failed to start grafana: %s", err.Error())
		os.Exit(1)
	}

	go func() {
		if _, err := io.Copy(os.Stdout, stdout); err != nil {
			log.Fatalf("failed to pipe stdout output: %s", err.Error())
			os.Exit(1)
		}
	}()

	go func() {
		if _, err := io.Copy(os.Stdout, stderr); err != nil {
			log.Fatalf("failed to pipe stderr output: %s", err.Error())
			os.Exit(1)
			return
		}
	}()
}

func main() {
	flag.Parse()

	configuration, err := config.InitializeAndReadConfiguration()
	if err != nil {
		panic(err)
	}

	log.Infof("start carp in version %s", Version)

	startPayloadInBackground(configuration)

	server, err := proxy.NewServer(configuration)
	if err != nil {
		panic(err)
	}

	err = server.ListenAndServe()
	if err != nil {
		panic(err)
	}
}
