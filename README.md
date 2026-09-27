# Minecraft na Oracle Cloud com Terraform

[![terraform](https://github.com/guilhermedecastrogt/minecraft-oracle-terraform/actions/workflows/terraform.yml/badge.svg)](https://github.com/guilhermedecastrogt/minecraft-oracle-terraform/actions/workflows/terraform.yml)

Infraestrutura como código para subir um servidor **Paper** numa VM ARM do
tier **Always Free** da Oracle Cloud. Um `terraform apply` cria a rede, o
firewall e a máquina, instala o Docker e deixa o servidor no ar — sem nenhum
passo manual depois.

Projeto de estudo: o objetivo é ter um servidor de verdade para jogar com os
amigos e, no caminho, encostar em VCN, security lists, cloud-init, imagens
ARM, Docker Compose e CI.

```
terraform apply
      │
      ▼
 Oracle Cloud (região sa-saopaulo-1)
      │
      ├── VCN 10.0.0.0/16
      │     ├── Internet Gateway
      │     ├── Route Table        0.0.0.0/0 → IGW
      │     ├── Security List      :22 (seu IP) · :25565 (mundo) · ICMP
      │     └── Subnet 10.0.1.0/24 (pública)
      │
      └── VM  VM.Standard.A1.Flex · 4 OCPU ARM · 24 GB · Ubuntu 24.04
            │
            └── cloud-init (primeiro boot)
                  ├── instala Docker
                  ├── abre a 25565 no iptables interno
                  └── docker compose up
                        ├── itzg/minecraft-server  →  Paper + Aikar flags
                        └── itzg/mc-backup         →  snapshot a cada 6 h
```

**Custo: R$ 0** dentro do Always Free — 4 OCPUs ARM, 24 GB de RAM e 200 GB de
disco, sem prazo para expirar. O projeto usa exatamente esse teto.

---

## Estrutura

```
.
├── .github/workflows/terraform.yml   CI: fmt, validate e lint do cloud-init
├── scripts/
│   ├── check-cloud-init.sh           renderiza o template e valida o YAML
│   └── apply-retry.sh                reaplica até haver capacidade ARM livre
└── terraform/
    ├── versions.tf                   versões do Terraform e do provider
    ├── providers.tf                  autenticação na OCI
    ├── variables.tf                  toda a configuração exposta
    ├── network.tf                    VCN, IGW, route table, security list, subnet
    ├── compute.tf                    imagem Ubuntu ARM + instância A1.Flex
    ├── outputs.tf                    IP e comandos prontos ao fim do apply
    ├── templates/
    │   └── cloud-init.yaml.tftpl     o que roda no primeiro boot da VM
    └── terraform.tfvars.example
```

## Pré-requisitos

| O quê | Como conseguir |
|---|---|
| Conta Oracle Cloud | [cloud.oracle.com](https://cloud.oracle.com) — pede cartão, mas recursos Always Free não geram cobrança |
| Terraform ≥ 1.5 | `brew install terraform` |
| Par de chaves SSH | `ssh-keygen -t ed25519 -C "minecraft"` |
| API Key da OCI | Console → perfil → **My profile** → **API keys** → **Add API key** |

Ao criar a API key a Oracle exibe um **Configuration file preview**. É de lá
que saem `tenancy_ocid`, `user_ocid`, `fingerprint` e `region`. Baixe a chave
privada, salve em `~/.oci/oci_api_key.pem` e rode `chmod 600` nela.

> Se puder, faça o upgrade da conta para **Pay As You Go**. Contas em *trial*
> quase sempre esbarram em `Out of host capacity` ao pedir ARM. Continua tudo
> gratuito enquanto você ficar dentro dos limites do Always Free.

## Subindo

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

terraform init
terraform plan
terraform apply
```

No `terraform.tfvars`, além das credenciais, vale ajustar:

| Variável | Padrão | Para quê |
|---|---|---|
| `allowed_ssh_cidr` | `0.0.0.0/0` | descubra seu IP com `curl ifconfig.me` e use `SEU_IP/32` |
| `ops` | vazio | nicks que viram operadores (`SeuNick,NickDoAmigo`) |
| `whitelist` | vazio | preencher liga a whitelist automaticamente |
| `java_memory` | `12G` | heap da JVM; deixe folga para SO e Docker |
| `difficulty` / `max_players` / `motd` | `normal` / `20` / — | ajustes do jogo |
| `availability_domain_index` | `0` | só útil em regiões com mais de um AD (São Paulo tem apenas um) |

Ao fim do apply:

```
server_address = "150.230.x.x:25565"
ssh            = "ssh ubuntu@150.230.x.x"
```

A VM nasce em cerca de um minuto, mas o cloud-init ainda precisa instalar o
Docker e baixar o Paper — **de 3 a 6 minutos no total**. Para acompanhar:

```bash
ssh ubuntu@<IP> 'sudo tail -f /var/log/cloud-init-output.log'   # provisionamento
ssh ubuntu@<IP> 'docker logs -f minecraft'                      # servidor
```

Quando aparecer `Done (x.xxxs)! For help, type "help"`, cole o `server_address`
no Minecraft em **Multiplayer → Add Server**.

## Operando o servidor

Entre com `ssh ubuntu@<IP>`. Os atalhos já vêm carregados no shell:

```bash
mc-logs        # logs ao vivo
mc-console     # console do Paper via RCON
mc-restart     # reinicia o container
mc-up          # sobe o compose
mc-down        # derruba o compose
```

Dentro do `mc-console`:

```
list
op SeuNick
whitelist add NickDoAmigo
say ola pessoal
stop
```

Onde ficam as coisas na VM:

| Caminho | Conteúdo |
|---|---|
| `/opt/minecraft/docker-compose.yml` | definição dos containers |
| `/opt/minecraft/data/` | mundo, `server.properties`, `plugins/`, logs |
| `/opt/minecraft/backups/` | backups automáticos (a cada 6 h, retenção de 7 dias) |

**Instalar um plugin:**

```bash
scp EssentialsX.jar ubuntu@<IP>:/opt/minecraft/data/plugins/
ssh ubuntu@<IP> 'docker restart minecraft'
```

**Baixar um backup:**

```bash
scp ubuntu@<IP>:/opt/minecraft/backups/*.tgz .
```

**Destruir tudo** (o mundo vai junto — baixe os backups antes):

```bash
terraform destroy
```

## Como as peças se encaixam

Três coisas que costumam pegar quem está começando:

**Existem dois firewalls, e os dois precisam liberar a porta.** A *security
list* da OCI filtra o pacote antes dele chegar na VM. O *iptables* de dentro do
Ubuntu filtra depois — e a imagem Ubuntu da Oracle já vem bloqueando tudo menos
SSH. Por isso o cloud-init abre a 25565 lá dentro também. Lembrar de um e
esquecer o outro é a causa número um de "o servidor subiu mas ninguém conecta".

**O cloud-init roda uma única vez.** Ele é entregue como `user_data` no
nascimento da VM. Alterar o template e rodar `apply` de novo **recria a
máquina** — e o mundo se perde. Para mudanças do dia a dia, edite direto na VM:

```bash
sudo nano /opt/minecraft/docker-compose.yml
docker compose -f /opt/minecraft/docker-compose.yml up -d
```

Na prática: o Terraform é a fonte da verdade da **infraestrutura**; a partir do
primeiro boot, a configuração do jogo vive na VM.

**A imagem base é buscada, não fixada.** `compute.tf` consulta a imagem Ubuntu
ARM mais recente em vez de gravar um OCID na mão, porque esses IDs mudam a cada
release. Como isso faria a VM ser recriada sempre que a Oracle publicasse uma
imagem nova, há um `ignore_changes` no `source_id`. Atualize o SO por dentro,
com `apt`.

## CI

O workflow roda em todo push e pull request:

- `terraform fmt -check -recursive` — formatação
- `terraform init -backend=false` + `terraform validate` — sintaxe e tipos
- `scripts/check-cloud-init.sh` — renderiza o template e garante que o
  cloud-init e o `docker-compose.yml` embutido são YAML válidos, com os dois
  serviços esperados

É validação apenas: nada de `apply` automático, porque isso exigiria as
credenciais da OCI como secrets do repositório. O caminho natural para chegar
lá é o primeiro item do roadmap.

Para rodar os mesmos checks localmente:

```bash
cd terraform && terraform fmt -check -recursive && terraform validate
./scripts/check-cloud-init.sh
```

## Problemas comuns

| Sintoma | Causa provável |
|---|---|
| `Out of host capacity` | capacidade ARM esgotada. Veja a seção abaixo |
| `404-NotAuthorizedOrNotFound` | OCID, fingerprint ou caminho da chave errados no `terraform.tfvars` |
| SSH funciona, o jogo não conecta | firewall interno. Confira com `sudo iptables -L INPUT -n --line-numbers` |
| `Connection refused` no cliente | o Paper ainda está baixando ou gerando o mundo. Veja `docker logs minecraft` |
| Servidor engasgando com muita gente | aumente `java_memory` ou reduza `VIEW_DISTANCE` no compose |

## Quando falta capacidade ARM

`Out of host capacity` é o obstáculo mais comum deste projeto, e **não é erro de
configuração**: o pool gratuito de Ampere A1 da região está cheio. O `apply`
cria a rede normalmente e falha só na instância, então basta reaplicar — nada
precisa ser refeito.

A capacidade abre em janelas curtas, quando alguém destrói uma instância. Quem
insiste, consegue:

```bash
./scripts/apply-retry.sh                 # tenta a cada 3 minutos, até conseguir
INTERVAL=300 ./scripts/apply-retry.sh    # a cada 5 minutos
MAX_TRIES=20 ./scripts/apply-retry.sh    # desiste depois de 20 tentativas
```

O script só repete quando o erro é de capacidade; qualquer outra falha ele
mostra e interrompe.

Se a espera se arrastar, três coisas aumentam a chance:

1. **Peça menos.** Um pedido de 4 OCPUs e 24 GB precisa de um bloco grande
   livre. Com `instance_ocpus = 2` e `instance_memory_gb = 12` a chance sobe
   bastante, e ainda sobra máquina para uma dúzia de amigos (ajuste
   `java_memory` para `8G` junto).
2. **Troque de região.** `sa-vinhedo-1` é o outro datacenter brasileiro e tem
   pool próprio. Mudar `region` recria tudo, mas a essa altura não há nada para
   perder.
3. **Saia do trial.** Contas em avaliação têm prioridade menor na fila de
   capacidade. Fazer upgrade para Pay As You Go ajuda e mantém os recursos
   Always Free gratuitos.

## Roadmap

- [ ] State remoto no OCI Object Storage + `apply` pelo CI com OIDC
- [ ] Domínio próprio com registro SRV (dispensa a porta no endereço)
- [ ] Geyser + Floodgate para deixar entrar jogadores do Bedrock
- [ ] Envio dos backups para Object Storage com `rclone`
- [ ] Métricas do servidor com Prometheus + Grafana

## Licença

MIT.
