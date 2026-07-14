# rhd_garage — Manual

Sistema de garagens com criador in-game: garagens públicas, de job/gang, compartilhadas, de casa, barcos, aeronaves, pátio da polícia e loja de veículos de serviço.

---

## Sumário

1. [Dependências](#dependências)
2. [Instalação](#instalação)
3. [Permissões (ACE)](#permissões-ace)
4. [Configuração](#configuração)
5. [Comandos](#comandos)
6. [Definição de garagens (`data/garages.json`)](#definição-de-garagens-datagaragesjson)
7. [Criador de garagens in-game](#criador-de-garagens-in-game)
8. [Pátio da polícia (impound)](#pátio-da-polícia-impound)
9. [Loja de veículos de job](#loja-de-veículos-de-job)
10. [Modo de desenvolvimento](#modo-de-desenvolvimento)
11. [Integrações](#integrações)
12. [Entrypoints para outros recursos](#entrypoints-para-outros-recursos)
13. [Localização](#localização)
14. [Estrutura de arquivos](#estrutura-de-arquivos)

---

## Dependências

| Recurso | Obrigatório | Observação |
|---|---|---|
| `ox_lib` | Sim | Declarado em `dependencies`. Callbacks, locale, zonas, menus, `lib.loadJson`, `lib.addCommand` |
| `oxmysql` | Sim | `@oxmysql/lib/MySQL.lua` nos `server_scripts` |
| `qbx_core` | Sim | `@qbx_core/modules/lib.lua` nos `shared_scripts`; `server/main.lua` usa `exports.qbx_core:GetPlayer` e `qbx.spawnVehicle` |
| `fivem-freecam` | Sim | Usado pelo criador de zonas (`modules/zone.lua`). Sem ele, `/garagelist` não consegue desenhar zonas |
| `ox_target` **ou** `qb-target` | Sim | Definido por `Config.Target`. Necessário para garagens com NPC, para o impound e para a loja de veículos de job |
| `qb-core` | Não | A bridge `bridge/framework/qb.lua` só carrega se o `qb-core` existir |
| `es_extended` | Não | A bridge `bridge/framework/esx.lua` só carrega se o `es_extended` existir |
| Recurso de combustível | Não | `Config.FuelScript` (`cdn-fuel`, `LegacyFuel`, `ox_fuel`, `ps-fuel`, `rhd_fuel`). O recurso chama `SetFuel`/`GetFuel` nele |
| `ox_lib` radial / `qb-radialmenu` / `rhd_radialmenu` | Não | Só se `Config.RadialMenu` for usado por alguma garagem com `interaction = "radial"` |
| `mri_Qcarkeys` | Não | Entrega e remove a chave do veículo automaticamente (veja [Integrações](#integrações)) |
| `ps-housing` / `qb-houses` / `qs-housing` | Não | Garagens de casa (`bridge/houses/qb.lua`) |

---

## Instalação

1. Copie a pasta `rhd_garage` para `resources/`.
2. Adicione ao `server.cfg`:
   ```
   ensure rhd_garage
   ```
3. Importe o SQL correspondente ao seu framework:
   - **QBCore / QBox** — `sql/qb.sql` (tabela `player_vehicles` + triggers)
   - **ESX** — `sql/esx.sql` (tabela `owned_vehicles` + triggers)
   - **Pátio da polícia (obrigatório se `Config.UsePoliceImpound = true`)** — `sql/rhd_garage.policeimpound.sql` (tabela `police_impound`)

   > Os triggers de `qb.sql` e `esx.sql` dependem da tabela `police_impound`. Importe `rhd_garage.policeimpound.sql` **antes** dos outros dois.

4. `server/db_update.lua` adiciona automaticamente as colunas `balance`, `paymentamount`, `paymentsleft` e `financetime` em `player_vehicles` no start, caso ainda não existam. Erros de coluna duplicada são ignorados.
5. **Conflitos** — remova ou desabilite o recurso de garagem anterior (`qb-garages`, `esx_garage` etc.). Este recurso escuta os eventos `qb-garages:client:*` apenas para receber dados de casa, e não convive com outro sistema de garagem ativo.
6. Após configurar todas as garagens, **desligue `Config.InDevelopment`**.

Não há itens de inventário a cadastrar no `ox_inventory`.

---

## Permissões (ACE)

Os comandos administrativos usam `lib.addCommand` com `restricted = 'group.admin'`, o que gera as ACEs `command.<nome>`:

```
add_ace group.admin command.garagelist allow
add_ace group.admin command.removeTemp allow
```

O acesso ao target de confisco do pátio da polícia é controlado por job/grade, não por ACE — veja `Config.PoliceImpound.Target.groups`.

---

## Configuração

Arquivo: `shared/config.lua`.

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `Config.Target` | string | Sim | `'ox'` (ox_target) ou `'qb'` (qb-target) |
| `Config.RadialMenu` | string | Sim | `'ox'`, `'qb'` ou `'rhd'`. Usado por garagens com `interaction = "radial"` |
| `Config.FuelScript` | string | Sim | Recurso de combustível chamado via `exports[Config.FuelScript]:SetFuel/GetFuel`. Aceita `rhd_fuel`, `ox_fuel`, `LegacyFuel`, `ps-fuel`, `cdn-fuel` |
| `Config.changeNamePrice` | number | Sim | Preço (em dinheiro) para renomear um veículo na garagem |
| `Config.SpawnInVehicle` | bool | Sim | Se `true`, o jogador entra direto no veículo ao retirá-lo |
| `Config.VehiclesInAllGarages` | bool | Sim | Se `true`, todos os veículos do jogador aparecem em todas as garagens, ignorando onde foram guardados |
| `Config.DisableVehicleCamera` | bool | Sim | Desativa a câmera de preview ao retirar o veículo |
| `Config.LocateVehicleOutGarage` | bool | Sim | Permite localizar no mapa veículos que estão fora da garagem |
| `Config.UseJobVechileShop` | bool | Sim | Liga a loja de veículos de job. Se `false`, `client/jobvehshop.lua` retorna imediatamente |
| `Config.UsePoliceImpound` | bool | Sim | Liga o sistema de pátio da polícia |
| `Config.InDevelopment` | bool | Sim | Modo de desenvolvimento: logs extras e comandos `/loaded` e `/reloadcache`. **Desligue em produção** |
| `Config.TransferVehicle.enable` | bool | Sim | Habilita a transferência de veículo entre jogadores |
| `Config.TransferVehicle.price` | number | Sim | Preço da transferência |
| `Config.SwapGarage.enable` | bool | Sim | Habilita a troca de garagem de um veículo |
| `Config.SwapGarage.price` | number | Sim | Preço da troca de garagem |
| `Config.GiveKeys.enable` | bool | Sim | Habilita o sistema de chaves |
| `Config.GiveKeys.onspawn` | bool | Sim | Dá a chave ao retirar o veículo e remove ao guardar (via `mri_Qcarkeys`) |
| `Config.GiveKeys.tempkeys` | bool | Sim | Entrega chaves temporárias ao spawnar o veículo |
| `Config.GiveKeys.price` | number | Sim | Preço da chave |
| `Config.IconAnimation` | string | Sim | Animação dos ícones do menu (ex.: `"fade"`) |
| `Config.Icons` | `[classe] = string` | Sim | Ícone exibido por classe de veículo (8 moto, 13 bicicleta, 14 barco, 15 helicóptero, 16 avião). Classes fora da tabela usam `car` |
| `Config.ImpoundPrice` | `[classe] = number` | Sim | Preço de liberação do pátio por classe de veículo (0 a 21) |
| `Config.PoliceImpound.Target.groups` | table | Sim | Jobs e grades autorizados a confiscar veículos (ex.: `{ police = 0 }`) |
| `Config.PoliceImpound.location` | array | Sim | Locais do pátio (veja abaixo) |
| `Config.JobVehicleShop` | array | Sim | Lojas de veículos por job (veja abaixo) |
| `Config.HouseGarages` | table | Sim | **Não editar.** Preenchida em runtime pela bridge de casas |

### `Config.PoliceImpound.location[i]`

| Campo | Tipo | Descrição |
|---|---|---|
| `label` | string | Nome do pátio |
| `blip.enable` | bool | Cria blip no mapa |
| `blip.sprite` | number | Sprite do blip |
| `blip.colour` | number | Cor do blip |
| `zones.points` | array de `vec3` | Polígono da zona do pátio |
| `zones.thickness` | number | Espessura da zona |

### `Config.JobVehicleShop[i]`

| Campo | Tipo | Descrição |
|---|---|---|
| `job` | string | Job dono da loja |
| `label` | string | Nome da loja |
| `ped.model` | string | Modelo do NPC vendedor |
| `ped.coords` | `vec4` | Posição e heading do NPC |
| `spawn` | `vec4` | Onde o veículo comprado nasce |
| `vehicle[model].price` | number | Preço do veículo |
| `vehicle[model].label` | string | Nome exibido |
| `vehicle[model].prefixPlate` | string | Prefixo da placa gerada (ex.: `POL`) |
| `vehicle[model].forRank` | `[grade] = bool` | Grades do job que podem comprar esse veículo |

---

## Comandos

| Comando | Permissão | Descrição |
|---|---|---|
| `/garagelist` | `command.garagelist` (group.admin) | Abre a lista de garagens: criar, editar, apagar e configurar pontos de spawn |
| `/removeTemp <id>` | `command.removeTemp` (group.admin) | Libera os veículos de aluguel travados de um jogador (limpa o cache `tempVehicle` do citizenid) |
| `/loaded` | Nenhuma (só com `Config.InDevelopment`) | Informa se os dados de garagem e do jogador já carregaram |
| `/reloadcache` | Nenhuma (só com `Config.InDevelopment`) | Recarrega o cache de dados do framework |

> O nome do comando `/garagelist` vem do locale (`command.admin.garagelist`), então muda junto com o idioma se você traduzir essa chave.

---

## Definição de garagens (`data/garages.json`)

A lista de garagens é um JSON carregado com `lib.loadJson('data.garages')` e exposto globalmente como `GarageZone`. A chave de cada entrada é o **nome da garagem**. O arquivo é reescrito pelo criador in-game — normalmente você não precisa editá-lo à mão.

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `type` | array de string | Sim | Tipos de veículo aceitos: `car`, `boat`, `helicopter`, `planes`, `motorcycle`, `cycles` |
| `zones.points` | array de `{x,y,z}` | Sim | Polígono da zona de interação |
| `zones.thickness` | number | Sim | Espessura da zona |
| `interaction` | string ou objeto | Sim | `"keypressed"` (tecla E), `"radial"` (menu radial) ou um objeto `{ model, coords }` para NPC com target |
| `spawnPoint` | array de `{x,y,z,w}` | Não | Vagas de spawn dos veículos, em ordem |
| `spawnPointVehicle` | array de string | Não | Modelo mostrado em cada vaga (preview de ocupação) |
| `blip.type` | number | Não | Sprite do blip |
| `blip.color` | number | Não | Cor do blip |
| `blip.label` | string | Não | Nome do blip. Se ausente, usa o nome da garagem |
| `impound` | bool | Não | Marca a garagem como pátio/seguradora |
| `shared` | bool | Não | Garagem compartilhada (veículos de todos os jogadores autorizados) |
| `job` | `[job] = grade` | Não | Restringe a garagem a jobs e grades. Ignorado quando `impound = true` |
| `gang` | `[gang] = grade` | Não | Restringe a garagem a gangs e grades. Ignorado quando `impound = true` |

Exemplo (garagem pública com tecla E):

```json
"Casino Parking": {
  "type": ["car", "cycles", "motorcycle"],
  "interaction": "keypressed",
  "impound": false,
  "shared": false,
  "blip": { "type": 357, "color": 3, "label": "Garagem Pública" },
  "zones": {
    "thickness": 4.0,
    "points": [
      { "x": 875.27, "y": -9.27, "z": 79.0 },
      { "x": 869.66, "y": -5.71, "z": 79.0 }
    ]
  },
  "spawnPoint": [{ "x": 871.12, "y": -8.40, "z": 78.49, "w": 237.5 }],
  "spawnPointVehicle": ["kuruma"]
}
```

Exemplo de interação com NPC:

```json
"interaction": {
  "model": "ig_tylerdix",
  "coords": { "x": -803.48, "y": -1495.81, "z": 1.60, "w": 290.0 }
}
```

Os modelos de ped disponíveis para o criador estão listados em `data/peds.json`.

---

## Criador de garagens in-game

O comando `/garagelist` (admin) abre a lista de garagens existentes e permite criar novas. O fluxo de criação pergunta:

1. **Nome da garagem** (vira a chave no `garages.json`).
2. **Tipos de veículo** — multi-select: Carros, Barcos, Helicóptero, Aviões, Motocicleta, Bicicleta.
3. **Usar blip** — se marcado, pede sprite, cor e label.
4. **Garagem de apreensão** (`impound`).
5. **Garagem de carros compartilhados** (`shared`).
6. **Garagem com vagas** — habilita a definição de pontos de spawn.
7. **Como abrir** — `radial` (menu radial), `keypressed` (tecla E) ou `targetped` (NPC com target).

Em seguida, a zona é desenhada com a câmera livre (`fivem-freecam`). Os controles aparecem na tela e vêm do locale `createzone`:

| Tecla | Ação |
|---|---|
| Setas / mouse | Mover a câmera |
| `R` / `F` | Coordenada Z |
| `Shift` + scroll | Altura da zona |
| `Espaço` | Criar um novo ponto |
| `Backspace` | Editar o último ponto |
| `Enter` | Salvar |
| `Esc` | Cancelar |

Ao salvar, o cliente dispara `rhd_garage:server:saveGarageZone`, o servidor grava o `data/garages.json` e faz broadcast de `rhd_garage:client:syncConfig`, que recria zonas e blips **sem restart**.

---

## Pátio da polícia (impound)

Ligado por `Config.UsePoliceImpound`. Requer a tabela `police_impound` (`sql/rhd_garage.policeimpound.sql`).

- **Confiscar** — policiais autorizados (`Config.PoliceImpound.Target.groups`) ganham uma opção de target em qualquer veículo. Ela registra o veículo no pátio junto com o oficial, a data e uma multa opcional.
- **Multa** — no ato do confisco, o policial pode definir um valor. A cobrança é enviada ao dono via `rhd_garage:server:policeImpound.sendBill`.
- **Liberação** — o dono vai até a zona do pátio, paga o valor de `Config.ImpoundPrice[classe]` e o veículo volta a ficar disponível.
- **Triggers SQL** — mantêm a tabela `police_impound` em sincronia: renomeiam a placa quando ela muda, apagam a linha quando o veículo é deletado e apagam a linha quando o estado do veículo deixa de ser "confiscado".

---

## Loja de veículos de job

Ligada por `Config.UseJobVechileShop`. Para cada entrada de `Config.JobVehicleShop`, um NPC é criado com target. O jogador do job correspondente escolhe um veículo da lista, vê um preview com câmera e compra.

A lista mostrada é filtrada pela **grade** do jogador (`forRank[grade] = true`) e por `IsModelValid`. A placa recebe o prefixo definido em `prefixPlate`.

---

## Modo de desenvolvimento

`Config.InDevelopment = true` habilita:

- Log JSON dos dados de spawn de veículo no console do cliente.
- Aviso periódico no console enquanto os dados de garagem não carregam.
- Os comandos `/loaded` e `/reloadcache`, registrados em `bridge/framework/qb.lua` e `bridge/framework/esx.lua`.

Como esses comandos não têm restrição de ACE, **desligue `Config.InDevelopment` em produção**.

---

## Integrações

### mri_Qcarkeys

Se o recurso estiver rodando e `Config.GiveKeys.onspawn = true`, o `rhd_garage` entrega a chave do veículo ao retirá-lo da garagem (`GiveKeyItem`) e a remove ao guardar (`RemoveKeyItem`), verificando antes se o jogador já tem uma chave permanente (`HavePermanentKey`).

### Garagens de casa (ps-housing / qb-houses / qs-housing)

`bridge/houses/qb.lua` detecta qual sistema de moradia está presente e escuta os eventos legacy do `qb-garages`:

- `qb-garages:client:setHouseGarage`
- `qb-garages:client:houseGarageConfig`
- `qb-garages:client:addHouseGarage`
- `qb-garages:client:removeHouseGarage`

A posse da casa é validada no servidor via `exports['ps-housing']:IsOwner(src, house)`. As garagens de casa entram em `Config.HouseGarages` em runtime.

### Menu radial

Garagens com `interaction = "radial"` registram as opções no menu radial escolhido por `Config.RadialMenu`:

- `'ox'` — menu radial do `ox_lib`
- `'qb'` — `exports['qb-radialmenu']:AddOption`
- `'rhd'` — `exports.rhd_radialmenu:addRadialItem`

As opções disparam os eventos `rhd_garage:radial:open`, `rhd_garage:radial:store` e `rhd_garage:radial:open_policeimpound`.

### Combustível

O nível de combustível é lido ao guardar e reaplicado ao retirar, via `exports[Config.FuelScript]:GetFuel(veh)` e `:SetFuel(veh, fuel)`. Qualquer recurso de combustível que exponha essas duas funções serve.

### Deformação

`modules/deformation.lua` salva e restaura a deformação da lataria (coluna `deformation` na tabela de veículos), preservando os amassados entre sessões.

### Telefone

O export `getvehForPhone` devolve a lista de veículos do jogador em formato pronto para apps de telefone.

---

## Entrypoints para outros recursos

### Exports de cliente

```lua
-- Abre o menu da garagem
exports.rhd_garage:openMenu({
    garage = 'Casino Parking',
    type = { 'car' },
    impound = false,
    shared = false,
    spawnpoint = spawnPoints,
    ignoreDist = true
})

-- Guarda o veículo atual (ou o mais próximo) na garagem
exports.rhd_garage:storeVehicle({ garage = 'Casino Parking', type = { 'car' } })

-- Abre o menu do pátio da polícia
exports.rhd_garage:openpoliceImpound({ label = 'Pátio do Detran' })

-- Marca no mapa a posição de um veículo que está fora da garagem
local found = exports.rhd_garage:trackveh(plate, garage, true) -- setPoint = true cria o waypoint

-- Lista de veículos do jogador, para apps de telefone
local vehicles = exports.rhd_garage:getvehForPhone()
```

O parâmetro `data` de `openMenu` e `storeVehicle` segue o tipo `GarageVehicleData`, documentado em `types.lua`.

### Export de servidor

```lua
-- Retorna a tabela completa de garagens (GarageZone)
local garages = exports.rhd_garage:Garage()
```

### Eventos de servidor

```lua
TriggerServerEvent('rhd_garage:server:updateState', { plate = plate, state = 1, garage = garage })
TriggerServerEvent('rhd_garage:server:saveGarageZone', fileData)
TriggerServerEvent('rhd_garage:server:saveCustomVehicleName', fileData)
TriggerServerEvent('rhd_garage:server:removeTemp', { model = model })
TriggerServerEvent('rhd_garage:server:buyVehicle', vehData)
TriggerServerEvent('rhd_garage:server:removeFromPoliceImpound', plate)
TriggerServerEvent('rhd_garage:server:policeImpound.sendBill', citizenid, fine, plate)
```

> `updateState`, `saveGarageZone`, `saveCustomVehicleName` e `removeTemp` rejeitam chamadas vindas de outro recurso (`if GetInvokingResource() then return end`) — só aceitam `TriggerServerEvent` do cliente.

### Callbacks de servidor (`lib.callback`)

```lua
lib.callback.await('rhd_garage:cb_server:getVehicleList', false, garage, impound, shared)
lib.callback.await('rhd_garage:cb_server:getVehicleInfoByPlate', false, plate)
lib.callback.await('rhd_garage:cb_server:getvehiclePropByPlate', false, plate)
lib.callback.await('rhd_garage:cb_server:getvehowner', false, plate, shared, pleaseUpdate)
lib.callback.await('rhd_garage:cb_server:getoutsideVehicleCoords', false, plate, garage)
lib.callback.await('rhd_garage:cb_server:GetPlayerVehiclesForPhone')
lib.callback.await('rhd_garage:cb_server:removeMoney', false, type, amount)
lib.callback.await('rhd_garage:cb_server:swapGarage', false, clientData)
lib.callback.await('rhd_garage:cb_server:transferVehicle', false, clientData)
lib.callback.await('rhd_garage:server:spawnVehicle', false, model, coords, props)
lib.callback.await('rhd_garage:cb_server:policeImpound.getVehicle', false, garage)
lib.callback.await('rhd_garage:cb_server:policeImpound.impoundveh', false, impoundData)
lib.callback.await('rhd_garage:cb_server:policeImpound.cekDate', false, date)
```

`rhd_garage:server:spawnVehicle` tem cooldown de 3 segundos por jogador — chamadas dentro da janela retornam `false, false`.

### Eventos de cliente

```lua
TriggerClientEvent('rhd_garage:client:garagelist', src)      -- abre o criador/lista de garagens
TriggerClientEvent('rhd_garage:client:syncConfig', -1, newGarageZone) -- recarrega zonas e blips sem restart
```

---

## Localização

As strings são traduzidas via locale do `ox_lib` (`ox_lib "locale"` no manifest). Os arquivos ficam em `locales/`:

- `en.json` — inglês
- `id.json` — indonésio
- `pt-br.json` — português do Brasil

O locale ativo é definido pela convar no `server.cfg`:

```
setr ox:locale "pt-br"
```

O nome do comando `/garagelist` também vem do locale (chave `command.admin.garagelist`).

---

## Estrutura de arquivos

```
rhd_garage/
├── client/
│   ├── main.lua              — menu da garagem, retirada e guarda de veículo, transferência, troca de garagem, renomear veículo
│   ├── zone.lua              — cria as zonas de cada garagem e resolve a interação (E / radial / NPC), checagem de job e gang
│   ├── blip.lua              — cria e atualiza os blips das garagens
│   ├── creator.lua           — /garagelist: criar, editar e apagar garagens in-game
│   ├── vehicle.lua           — utilidades de veículo, rastreio por placa e exports trackveh/getvehForPhone
│   ├── police_impound.lua    — target de confisco, zona e menu do pátio, multa
│   └── jobvehshop.lua        — NPC e menu da loja de veículos de job
├── server/
│   ├── main.lua              — callbacks da garagem, spawn de veículo, gravação de arquivos, /removeTemp, export Garage
│   ├── vehicle.lua           — consultas de veículo (lista para telefone, coordenadas fora da garagem)
│   ├── storage.lua           — escrita de data/garages.json e data/vehiclesname.json
│   ├── police_impound.lua    — confisco, liberação e cobrança de multa
│   ├── jobvehshop.lua        — compra de veículo de job
│   ├── command.lua           — comando /garagelist
│   └── db_update.lua         — adiciona colunas de financiamento em player_vehicles no start
├── shared/
│   ├── config.lua            — configuração principal; carrega garages.json e vehiclesname.json
│   └── utils.lua             — notificações, drawtext, menus, target de ped, combustível, checagem de job/gang
├── bridge/
│   ├── framework/qb.lua      — bridge QBCore/QBox (só carrega se qb-core existir)
│   ├── framework/esx.lua     — bridge ESX (só carrega se es_extended existir)
│   ├── houses/qb.lua         — garagens de casa (ps-housing / qb-houses / qs-housing)
│   ├── radialmenu/ox.lua     — menu radial do ox_lib
│   ├── radialmenu/qb.lua     — menu radial do qb-radialmenu
│   └── radialmenu/rhd.lua    — menu radial do rhd_radialmenu
├── modules/
│   ├── zone.lua              — desenho de polyzone com câmera livre (fivem-freecam)
│   ├── debugzone.lua         — visualização das zonas em debug
│   ├── spawnpoint.lua        — definição e checagem das vagas de spawn
│   ├── pedcreator.lua        — criação do NPC de interação
│   └── deformation.lua       — salvar e restaurar a deformação da lataria
├── data/
│   ├── garages.json          — lista de garagens (fonte da verdade, escrita pelo criador in-game)
│   ├── peds.json             — modelos de ped disponíveis no criador
│   └── vehiclesname.json     — nomes customizados de veículos
├── locales/
│   ├── en.json
│   ├── id.json
│   └── pt-br.json
├── sql/
│   ├── qb.sql                — tabela player_vehicles + triggers do impound
│   ├── esx.sql               — tabela owned_vehicles + triggers do impound
│   └── rhd_garage.policeimpound.sql — tabela police_impound
├── types.lua                 — anotações de tipo (GarageData, GarageVehicleData, RadialData, utils)
└── fxmanifest.lua
```
