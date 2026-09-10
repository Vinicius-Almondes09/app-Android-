# Trabalho 02 – Sistemas Distribuídos

## Aplicativo Android para Detecção de Objetos (Foto via Botão → Servidor Python por Sockets)

Este projeto implementa a **Atividade 2** da disciplina de Sistemas Distribuídos: um
**aplicativo Android (Flutter)** tira uma foto e a envia via **Socket TCP** para um
**servidor Python**, que executa a **detecção de objetos** com o modelo **YOLO11n**
(OpenCV/Ultralytics) e retorna ao aplicativo os objetos identificados.

```
Celular (app Flutter)          PC (servidor Python)
        │                              │
        ▼                              │
 Captura da foto                      │
        │                              │
 JPEG – qualidade 80                  │
 largura ≤ 1280 px                    │
        │                              │
 Socket TCP ── 4 bytes (tamanho) ────►│
 Socket TCP ── bytes da foto ────────►│
        │                              ▼
        │                    Recebe, salva (timestamp)
        │                    e roda YOLO11n
        │                              │
        │◄──── resposta (objetos) ─────│
        ▼                              │
 Resultado na tela                    │
```

---

## 1. O que você precisa baixar/instalar

### No notebook (PC que vai rodar o servidor)

| Item | Onde baixar | Por quê |
|---|---|---|
| **Python 3.10 ou superior** | https://www.python.org/downloads/ | O servidor é escrito em Python. No Windows, marque a opção **"Add Python to PATH"** na instalação |
| **O código deste projeto** | Clone do GitHub (ou a pasta `.zip`) | Contém o servidor, o app e o modelo `yolo11n.pt` |
| **Bibliotecas Python** | Instaladas via `pip` (passo a passo abaixo) | `ultralytics` (YOLO11n) e `opencv-python` (processamento de imagem) |

> ⚠️ O modelo `yolo11n.pt` **já vem dentro da pasta `servidor/`** — não precisa baixar
> separadamente. Se ele estiver faltando, o Ultralytics baixa automaticamente na
> primeira execução (é preciso internet).

### No notebook (somente se quiser gerar/alterar o app)

| Item | Onde baixar | Por quê |
|---|---|---|
| **Flutter SDK** | https://docs.flutter.dev/get-started/install | Compila o app Android |
| **Android Studio** | https://developer.android.com/studio | SDK Android, emulador e ferramentas de build |
| **Git** | https://git-scm.com/ | Para clonar o repositório |

> 💡 **Não é obrigatório ter Flutter/Android Studio**: se você só quer usar o app,
> instale direto no celular o APK pronto (`app-debug.apk`, gerado com
> `flutter build apk --debug --target-platform android-arm64`). O Flutter só é
> necessário para recompilar ou alterar o aplicativo.

### No celular (Android)

| Item | Onde baixar | Por quê |
|---|---|---|
| **O APK do app** | Copie `app_detector/build/app/outputs/flutter-apk/app-debug.apk` para o celular (ou use `flutter run` com cabo USB) | É o aplicativo que tira a foto e conversa com o servidor |

Além disso, o celular precisa:
- **Estar na mesma rede Wi-Fi que o notebook** (mesmo roteador; evite redes "guest" ou de convidados, que costumam isolar os aparelhos).
- **Permitir instalação de apps de fontes desconhecidas** (o Android pede autorização na hora de instalar o APK).

---

## 2. Passo a passo – Rodando o servidor no PC

Abra o terminal (Prompt de Comando/PowerShell no Windows, Terminal no Linux/macOS) e:

```bash
# 1. Entre na pasta do servidor
cd servidor

# 2. Crie o ambiente virtual (só na primeira vez)
python -m venv venv

# 3. Ative o ambiente virtual
# Windows (PowerShell):
venv\Scripts\Activate.ps1
# Windows (Prompt de Comando):
venv\Scripts\activate.bat
# Linux/macOS:
source venv/bin/activate

# 4. Instale as dependências (só na primeira vez)
pip install -r requirements.txt
```

> ⏳ O `pip install` baixa o `ultralytics` e o PyTorch (pode levar alguns minutos e
> ocupar ~2 GB). É normal demorar.

```bash
# 5. Inicie o servidor
python server.py
```

Resultado esperado:

```
==============================
 SERVIDOR DE DETECÇÃO
==============================
Porta: 8080
IPs deste computador:
  192.168.43.10
Descoberta automática ativa (UDP porta 8081).
Aguardando imagem...
```

> 💡 A **descoberta automática** (botão **Procurar servidor** do app) usa UDP na
> porta 8081. Se quiser que ela funcione, libere também a porta UDP no firewall:
>
> ```powershell
> netsh advfirewall firewall add rule name="Detector SD Descoberta" dir=in action=allow protocol=UDP localport=8081 profile=any
> ```
>
> Sem essa regra, o botão de busca não encontra o servidor (mas digitar o IP
> manualmente continua funcionando, com a regra TCP abaixo).

O servidor fica **aguardando imagens o tempo todo**. Deixe esta janela aberta.

> ⚠️ **Trocou de rede (hotspot, cabo USB, outro Wi-Fi)? O IP do notebook muda!**
> Use sempre o IP exibido na própria janela do servidor ("IPs deste computador")
> para a rede atual: hotspot do celular costuma ser `192.168.43.x` e tethering USB
> `192.168.42.x`. O hotspot/tethering também costuma ser tratado pelo Windows como
> rede **"Pública"** — por isso a regra do firewall deve usar `profile=any`.

### Liberar o firewall (Windows) — importante!

Na primeira execução, o Windows pode perguntar se deseja permitir o Python na rede.
Clique em **Permitir acesso** (redes privadas). Se já fechou essa janela e o celular
não consegue conectar, libere manualmente:

```powershell
netsh advfirewall firewall add rule name="Python Server" dir=in action=allow program="C:\caminho\do\seu\python.exe" enable=yes
```

Ou, liberando diretamente a **porta TCP 8080** (mais simples e cobre todos os perfis de rede):

```powershell
netsh advfirewall firewall add rule name="Detector SD" dir=in action=allow protocol=TCP localport=8080 profile=any
```

> 💡 **Por que `profile=any`?** Ao conectar no hotspot do celular (ou tethering USB),
> o Windows classifica a rede como **Pública** e aplica o bloqueio mais restritivo.
> Regras criadas só para redes privadas (ou a janela "Permitir acesso" respondida
> sem marcar ambas as redes) não valem nesses casos. `profile=any` cobre tudo.

Ou: **Configurações → Firewall do Windows Defender → Permitir um aplicativo → Python**.

---

## 3. Descobrindo o IP do notebook

O celular precisa do **endereço IPv4** do notebook na rede local:

| Sistema | Comando |
|---|---|
| Windows | `ipconfig` (procure por "Endereço IPv4", ex.: `192.168.0.105`) |
| Linux | `ip a` ou `hostname -I` |
| macOS | `ifconfig` ou `ipconfig getifaddr en0` |

> ⚠️ **Não use `127.0.0.1` nem `localhost` no celular**: para o celular, esses
> endereços apontam para o **próprio celular**, não para o seu PC.

---

## 4. Passo a passo – Usando o app no celular

### Opção A – Instalar o APK (mais simples)

1. Gere o APK no notebook (pasta `app_detector`):
   ```bash
   cd app_detector
   flutter build apk --debug --target-platform android-arm64
   ```
   O arquivo sai em `app_detector/build/app/outputs/flutter-apk/app-debug.apk`.
2. Copie o APK para o celular (cabo USB, Google Drive, WhatsApp, etc.) e toque nele
   para instalar (autorize "fontes desconhecidas" se pedir).
3. Abra o aplicativo **Detector de Objetos** e permita o acesso à **câmera**.

### Opção B – Rodar pelo cabo USB (para desenvolvimento)

1. No celular, ative **Opções do desenvolvedor** (toque 7 vezes em "Número da versão"
   em Configurações → Sobre o telefone) e ligue a **Depuração USB**.
2. Conecte o celular ao notebook por cabo USB.
3. Na pasta `app_detector`:
   ```bash
   flutter pub get
   flutter devices        # confirme que o celular aparece
   flutter run
   ```

### Conectando celular e notebook (importante!)

> ⚠️ **O Wi-Fi da UFPI (e da maioria das universidades) bloqueia a comunicação
> direta entre aparelhos** — celular e notebook não conseguem se enxergar, em
> nenhuma porta, mesmo com tudo configurado certo (o app dá "tempo esgotado na
> conexão"). Isso não tem conserto pelo lado do app.

**Opção A – Hotspot do celular (recomendada, funciona sempre)**

1. No **celular**: Configurações → **Ponto de acesso / Hotspot** → ative.
2. No **notebook**: conecte o Wi-Fi **no hotspot do celular** (não no da UFPI!).
3. Abra o app → toque em **Procurar servidor** → ele preenche IP e porta sozinho.
4. Toque em **Tirar e Analisar**.

**Opção B – Cabo USB (tethering, alternativa ao hotspot)**

1. Conecte o celular no notebook por cabo USB.
2. Ative **Configurações → Rede → Compartilhamento de internet por USB**
   (tethering USB). O celular passa a enxergar o notebook nessa rede,
   sem depender de Wi-Fi.
3. Abra o app → **Procurar servidor** → **Tirar e Analisar**.

> 💡 Essas redes são criadas pelo **seu** celular, então nada é bloqueado:
> não há isolamento de clientes, e o hotspot não precisa de internet móvel
> para o app funcionar (o tráfego é só celular ↔ notebook).

### Usando o aplicativo

1. Toque em **Procurar servidor**. O app envia um "ping" em broadcast na rede e
   preenche **IP** e **Porta** automaticamente quando o servidor responde:
   - **"Servidor encontrado!"** → pronto para usar.
   - **"Nenhum servidor encontrado"** → confira se o `server.py` está rodando e
     se celular e notebook estão na mesma rede (no Wi-Fi da UFPI não funciona;
     use hotspot ou cabo USB, como explicado acima).
   - Prefere digitar manualmente? Preencha IP e Porta à mão e siga normal.
2. Toque em **Tirar e Analisar**.
3. O app captura a foto, envia ao servidor e mostra o resultado:
   - `Pessoa detectada`
   - `Carro detectado`
   - `Cadeira detectada`
   - `Mochila detectada`
   - ou `Nada Detectado`
4. Toque novamente em **Tirar e Analisar** para uma nova foto → o servidor analisa de
   novo e o resultado é atualizado.

---

## 5. Testando o servidor sem o celular

Antes (ou sem) usar o app, é possível validar o servidor com um cliente Python:

```bash
cd servidor
python cliente_teste.py                # gera uma imagem de teste automaticamente
python cliente_teste.py caminho/foto.jpg   # ou envia uma foto existente

# Testar a partir de outra máquina da rede (ex.: simulando o celular):
python cliente_teste.py --host 192.168.0.105 --porta 8080

# Apenas validar a conexão (sonda rápida, sem enviar imagem):
python cliente_teste.py --host 192.168.0.105 --testar

# Descobrir o servidor na rede automaticamente (broadcast UDP):
python cliente_teste.py --descobrir
```

O servidor deve responder com os objetos detectados ou `Nada Detectado`.

> 💡 O botão **Testar conexão** do app envia exatamente essa mesma sonda
> (4 bytes com tamanho 0), que o servidor responde com `OK` sem processar nada.

---

## 6. Protocolo de comunicação

A comunicação entre o app e o servidor usa **Socket TCP** com o protocolo:

```
4 bytes (tamanho da imagem, inteiro de 32 bits Big Endian) + N bytes (foto JPEG)
```

**Casos especiais do protocolo:**

- **Tamanho `0`** → sonda de teste de conexão (botão **Testar conexão** do app e
  `cliente_teste.py --testar`). O servidor responde `OK` imediatamente, sem
  processar imagem.

| Etapa | Quem envia | Conteúdo |
|---|---|---|
| 1 | Aplicativo | 4 bytes com o tamanho da foto |
| 2 | Aplicativo | Bytes da foto em JPEG |
| 3 | Servidor | Texto com os objetos detectados (separados por vírgula) ou `Nada Detectado` |

A foto é preparada no app: **JPEG com qualidade ~80** e **largura máxima de 1280 px**
(redimensionada quando necessário). O servidor salva cada foto em
`servidor/recebidas/` com nome contendo data/hora/milissegundos
(ex.: `foto_20260908_124150_123.jpg`).

---

## 7. Detecção de objetos

- Biblioteca: **Ultralytics** (`ultralytics`)
- Modelo: **YOLO11n** (`servidor/yolo11n.pt`)
- Processamento de imagem: **OpenCV** (`opencv-python`)
- Código: `servidor/detector.py`

Exemplos de classes que o modelo reconhece: `person`, `car`, `chair`, `backpack` —
exibidas no app em português (Pessoa, Carro, Cadeira, Mochila). Qualquer outra classe
do COCO (80 classes) também é retornada com o nome original em inglês.

---

## 8. Estrutura do projeto

```
.
├── servidor/
│   ├── server.py            # Servidor Socket TCP
│   ├── detector.py          # Detecção com YOLO11n
│   ├── cliente_teste.py     # Cliente de teste (sem celular)
│   ├── requirements.txt     # Dependências Python
│   ├── yolo11n.pt           # Modelo de detecção
│   └── recebidas/           # Fotos recebidas (criada automaticamente)
│
├── app_detector/            # Aplicativo Flutter
│   ├── lib/main.dart        # Código principal do app
│   ├── pubspec.yaml         # Dependências (camera, image)
│   └── android/             # Projeto Android gerado pelo Flutter
│
└── README.md
```

---

## 9. Solução de problemas

| Problema | Causa provável / Solução |
|---|---|
| **"Tempo esgotado na conexão"** (errno 110) | Os pacotes estão sendo **descartados** antes de chegar ao servidor. Causas: celular usando **dados móveis** (desligue o 4G/5G), **firewall descartando** a porta 8080 (libere com `netsh advfirewall firewall add rule name="Detector SD" dir=in action=allow protocol=TCP localport=8080 profile=any`), **IP errado** (use o IPv4 do adaptador Wi-Fi ativo; VPN/WSL criam IPs falsos) ou **isolamento de clientes** na rede (use hotspot do celular). Confirme com o botão **Testar conexão** |
| **Não conecta mesmo com hotspot ou cabo USB** | 1. **O IP do notebook mudou!** Ao trocar de rede o IP é outro: hotspot do celular costuma ser `192.168.43.x`, tethering USB `192.168.42.x` — confira o IP atual na janela do `server.py` ("IPs deste computador") e digite-o no app. 2. O Windows trata hotspot/tethering como rede **"Pública"** e bloqueia a porta: a regra do firewall precisa usar `profile=any` (comando acima) — a janela "Permitir acesso" do Python costuma liberar só redes privadas. 3. No tethering USB, confirme que o **Compartilhamento de internet por USB** está ativo no celular |
| **"Conexão recusada"** | O servidor não está escutando na porta 8080 (confira se a janela mostra "Aguardando imagem...") |
| **"A foto foi enviada, mas o servidor não respondeu em 60 s"** | A conexão e o envio funcionaram — o problema é o processamento. Veja a janela do servidor: a primeira detecção pode levar 5–15 s (warm-up do YOLO); se passar disso, o servidor travou ou está lento demais |
| "Falha ao enviar a foto" | Conexão caiu no meio do upload (rede Wi-Fi fraca) — tente de novo |
| O celular não conecta | Os dois aparelhos precisam estar na **mesma rede Wi-Fi**, na **mesma sub-rede** (ex.: ambos `192.168.0.x`) e **sem dados móveis** no celular. Teste com `python cliente_teste.py --host IP_DO_PC --testar` a partir de outro PC da rede |
| Erro de câmera ao abrir o app | Permissão de câmera negada — conceda em Configurações do Android ou reinstale o APK |
| `flutter` não é reconhecido | Flutter não está no PATH — use o caminho completo ou adicione ao PATH |
| Demora no primeiro `pip install` | O PyTorch/Ultralytics é grande (~2 GB); é normal |
| Duas fotos no mesmo segundo | Agora o nome inclui milissegundos, então nenhuma foto é sobrescrita |

---

## 10. Capturas de tela

*Capturas a adicionar após o teste em dispositivo físico:*

- **Tela do aplicativo** (com o preview da câmera, IP e porta):

  `[CAPTURA DE TELA DO APP]`

- **Imagem capturada** (exibida no app após "Tirar e Analisar"):

  `[CAPTURA DA IMAGEM CAPTURADA]`

- **Resultado da detecção** (objetos detectados na tela do app):

  `[CAPTURA DO RESULTADO DA DETECÇÃO]`

---

## 11. Requisitos da entrega (checklist)

- [x] App Android (Flutter) que captura foto com o pacote `camera`
- [x] Envio via Socket TCP (`dart:io`) com protocolo `4 bytes + imagem`
- [x] Foto em JPEG, qualidade ~80, largura máxima de 1280 px
- [x] Servidor Python com Socket TCP, OpenCV e YOLO11n
- [x] Servidor salva a imagem recebida com timestamp
- [x] Servidor retorna os objetos identificados
- [x] App exibe o resultado ("Pessoa detectada", ..., ou "Nada Detectado")
- [x] Nova foto → nova análise com resultado atualizado
- [x] README com como rodar servidor e app, configuração de IP/porta, código e modelo
- [ ] Capturas de tela do app, imagem capturada e resultado da detecção (após teste no celular)

---

## 12. Notas de desenvolvimento

- O APK foi compilado para **ARM64** (`--target-platform android-arm64`), a
  arquitetura dos celulares Android atuais.
- Evite parênteses no caminho da pasta do projeto (ex.: `trabalho_02_(SD)`), pois o
  Gradle no Windows pode falhar — use nomes como `trabalho_02_SD`.
- O pacote `image` é usado para corrigir a orientação (EXIF) da foto antes do envio,
  garantindo que a imagem chegue "em pé" ao servidor.