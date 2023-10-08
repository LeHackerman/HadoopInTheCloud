# Hadoop In The Cloud

Hadoop In The Cloud is a deployment, configuration and control automation tool used to simplify running a Hadoop multi-node cluster in a cloud environment. All he provisionning, key generation, installation and configuration needed to run a Hadoop cluster is covered by this tool. All in all, it allows you to use Hadoop in a multi-node fashion starting from scratch. For now, it only supports Microsoft Azure.

## Installation

No installation is required, this tool is portable. Although some dependencies are installed locally in the tool's folder during the first run.  
So, just clone it.
```bash
git clone https://github.com/LeHackerman/HadoopInTheCloud.git
```

## Requirements
This tool requries:
- Python3
- Python3-venv
- jq  
Install them using your system's package manager.

## Usage
The tool SHOULD be ran from its parent directory. Don't call it from other locations it as it depends on some relative paths. (This is temporary as I wrote the script in a hurry. A future update will make the tool more conform to the UNIX paradigm)

```bash
./hitc.sh
```
## Roadmap

- [x] Write a playbook that provisions the necessary infrastructure.
- [x] Write a playbook that installs and configures Hadoop in a supplied resource group.
- [x] Write a dynamic inventory file to allow a certain modularity and decoupling between the playbooks and the infrastructure.
- [x] Write a shell script that automates the login, dependency installation and orchestration of playbooks.
- [ ] Configure traps for a cleaner and more reliable execution.
- [ ] Write playbooks to automate: The launch, stop and deletion of the machines / resource group.
- [ ] Add argument passing capabilties to the script.
- [ ] Decouple script's dependence to its parent directory and align with the UNIX paradigm.

## Contributing

Just make a pull request or hmu or smthg ¯\_(ツ)_/¯ .

## Nota Bene
- This is an alpha release. So, the tool is pretty sensitive to environmental misconfiguration. If it fails in any way, just execute ` rm -rf ./.ansible ./.az ./.ssh` and run it again.
- DO NOT USE THIS IN PRODUCTION. The tool was made with academic usage in mind, so, some security risks were tolerated. But, those can't be tolerated in a professional environment.
- Some values are parametrized and could be modified accordingly such as the Azure subscription to use, the number of nodes, the resource group name, etc. But, these are hardcoded in the shell script. So, if you wat to change them, either change the hardcoded values or tell me and I'll add the option of passing them as arguments.
## License

[GPLv3](https://choosealicense.com/licenses/gpl-3.0/)