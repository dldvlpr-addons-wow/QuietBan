-- Locales.lua : texts shown to the player, one table per client language.
-- Loaded before QuietBan.lua. A key missing from a language falls back to enUS.
-- Slash command words (ban, unban, list) stay in English in every language.
local _, NS = ...

local translations = {}

translations.enUS = {
    BANNED_PLAYER = "Banned player %s.",
    UNBANNED_PLAYER = "Unbanned player %s.",
    NOT_IN_LIST = "Not in the ban list: %s",
    NEED_NAME = "Give a name or target a player.",
    HELP_BAN = "/qb ban <name>  - ban a player (no name: your target)",
    HELP_UNBAN = "/qb unban <name>  - remove a ban",
    HELP_LIST = "/qb list  - show the bans",
    NO_BAN = "No ban.",
    UNBAN = "Unban",
    MENU_BAN_PLAYER = "Ban player",
    IGNORE_IMPORTED = "Players imported from the Blizzard ignore list: %d.",
    TITLE_BANS = "QuietBan - Bans",
}

translations.frFR = {
    BANNED_PLAYER = "Joueur banni : %s.",
    UNBANNED_PLAYER = "Joueur débanni : %s.",
    NOT_IN_LIST = "Absent de la liste des bannis : %s",
    NEED_NAME = "Indique un nom ou cible un joueur.",
    HELP_BAN = "/qb ban <nom>  - bannir un joueur (sans nom : ta cible)",
    HELP_UNBAN = "/qb unban <nom>  - retirer un bannissement",
    HELP_LIST = "/qb list  - afficher les bannis",
    NO_BAN = "Aucun banni.",
    UNBAN = "Débannir",
    MENU_BAN_PLAYER = "Bannir le joueur",
    IGNORE_IMPORTED = "Joueurs importés depuis la liste d'ignorés Blizzard : %d.",
    TITLE_BANS = "QuietBan - Bannis",
}

translations.deDE = {
    BANNED_PLAYER = "Spieler gebannt: %s.",
    UNBANNED_PLAYER = "Spieler entbannt: %s.",
    NOT_IN_LIST = "Nicht auf der Bannliste: %s",
    NEED_NAME = "Gib einen Namen an oder wähle einen Spieler als Ziel.",
    HELP_BAN = "/qb ban <Name>  - einen Spieler bannen (ohne Name: dein Ziel)",
    HELP_UNBAN = "/qb unban <Name>  - einen Bann aufheben",
    HELP_LIST = "/qb list  - Banns anzeigen",
    NO_BAN = "Kein Bann.",
    UNBAN = "Entbannen",
    MENU_BAN_PLAYER = "Spieler bannen",
    IGNORE_IMPORTED = "Aus der Blizzard-Ignorierliste importierte Spieler: %d.",
    TITLE_BANS = "QuietBan - Banns",
}

translations.esES = {
    BANNED_PLAYER = "Jugador baneado: %s.",
    UNBANNED_PLAYER = "Jugador desbaneado: %s.",
    NOT_IN_LIST = "No está en la lista de baneos: %s",
    NEED_NAME = "Indica un nombre o selecciona a un jugador.",
    HELP_BAN = "/qb ban <nombre>  - banear a un jugador (sin nombre: tu objetivo)",
    HELP_UNBAN = "/qb unban <nombre>  - quitar un baneo",
    HELP_LIST = "/qb list  - mostrar los baneos",
    NO_BAN = "Ningún baneo.",
    UNBAN = "Desbanear",
    MENU_BAN_PLAYER = "Banear jugador",
    IGNORE_IMPORTED = "Jugadores importados de la lista de ignorados de Blizzard: %d.",
    TITLE_BANS = "QuietBan - Baneos",
}
translations.esMX = translations.esES

translations.itIT = {
    BANNED_PLAYER = "Giocatore bannato: %s.",
    UNBANNED_PLAYER = "Giocatore sbannato: %s.",
    NOT_IN_LIST = "Non è nella lista dei ban: %s",
    NEED_NAME = "Indica un nome o seleziona un giocatore.",
    HELP_BAN = "/qb ban <nome>  - bannare un giocatore (senza nome: il tuo bersaglio)",
    HELP_UNBAN = "/qb unban <nome>  - rimuovere un ban",
    HELP_LIST = "/qb list  - mostrare i ban",
    NO_BAN = "Nessun ban.",
    UNBAN = "Sbanna",
    MENU_BAN_PLAYER = "Banna giocatore",
    IGNORE_IMPORTED = "Giocatori importati dalla lista ignorati di Blizzard: %d.",
    TITLE_BANS = "QuietBan - Ban",
}

translations.ptBR = {
    BANNED_PLAYER = "Jogador banido: %s.",
    UNBANNED_PLAYER = "Jogador desbanido: %s.",
    NOT_IN_LIST = "Não está na lista de banidos: %s",
    NEED_NAME = "Informe um nome ou selecione um jogador.",
    HELP_BAN = "/qb ban <nome>  - banir um jogador (sem nome: seu alvo)",
    HELP_UNBAN = "/qb unban <nome>  - remover um banimento",
    HELP_LIST = "/qb list  - mostrar os banidos",
    NO_BAN = "Nenhum banido.",
    UNBAN = "Desbanir",
    MENU_BAN_PLAYER = "Banir jogador",
    IGNORE_IMPORTED = "Jogadores importados da lista de ignorados da Blizzard: %d.",
    TITLE_BANS = "QuietBan - Banidos",
}

translations.ruRU = {
    BANNED_PLAYER = "Игрок забанен: %s.",
    UNBANNED_PLAYER = "Игрок разбанен: %s.",
    NOT_IN_LIST = "Нет в списке банов: %s",
    NEED_NAME = "Укажите имя или возьмите игрока в цель.",
    HELP_BAN = "/qb ban <имя>  - забанить игрока (без имени: ваша цель)",
    HELP_UNBAN = "/qb unban <имя>  - снять бан",
    HELP_LIST = "/qb list  - показать баны",
    NO_BAN = "Банов нет.",
    UNBAN = "Разбанить",
    MENU_BAN_PLAYER = "Забанить игрока",
    IGNORE_IMPORTED = "Импортировано игроков из списка игнорирования Blizzard: %d.",
    TITLE_BANS = "QuietBan - Баны",
}

translations.koKR = {
    BANNED_PLAYER = "플레이어 차단됨: %s.",
    UNBANNED_PLAYER = "플레이어 차단 해제됨: %s.",
    NOT_IN_LIST = "차단 목록에 없음: %s",
    NEED_NAME = "이름을 입력하거나 플레이어를 대상으로 지정하세요.",
    HELP_BAN = "/qb ban <이름>  - 플레이어 차단 (이름 없음: 현재 대상)",
    HELP_UNBAN = "/qb unban <이름>  - 차단 해제",
    HELP_LIST = "/qb list  - 차단 목록 보기",
    NO_BAN = "차단 없음.",
    UNBAN = "차단 해제",
    MENU_BAN_PLAYER = "플레이어 차단",
    IGNORE_IMPORTED = "Blizzard 차단 목록에서 플레이어 %d명을 가져왔습니다.",
    TITLE_BANS = "QuietBan - 차단 목록",
}

translations.zhCN = {
    BANNED_PLAYER = "已屏蔽玩家：%s。",
    UNBANNED_PLAYER = "已解除屏蔽玩家：%s。",
    NOT_IN_LIST = "不在屏蔽列表中：%s",
    NEED_NAME = "请输入名字或选中一名玩家。",
    HELP_BAN = "/qb ban <名字>  - 屏蔽玩家（不填名字：当前目标）",
    HELP_UNBAN = "/qb unban <名字>  - 解除屏蔽",
    HELP_LIST = "/qb list  - 显示屏蔽列表",
    NO_BAN = "无屏蔽。",
    UNBAN = "解除屏蔽",
    MENU_BAN_PLAYER = "屏蔽玩家",
    IGNORE_IMPORTED = "已从暴雪屏蔽列表导入 %d 名玩家。",
    TITLE_BANS = "QuietBan - 屏蔽列表",
}

translations.zhTW = {
    BANNED_PLAYER = "已封鎖玩家：%s。",
    UNBANNED_PLAYER = "已解除封鎖玩家：%s。",
    NOT_IN_LIST = "不在封鎖清單中：%s",
    NEED_NAME = "請輸入名字或選取一名玩家。",
    HELP_BAN = "/qb ban <名字>  - 封鎖玩家（不填名字：目前目標）",
    HELP_UNBAN = "/qb unban <名字>  - 解除封鎖",
    HELP_LIST = "/qb list  - 顯示封鎖清單",
    NO_BAN = "無封鎖。",
    UNBAN = "解除封鎖",
    MENU_BAN_PLAYER = "封鎖玩家",
    IGNORE_IMPORTED = "已從暴雪忽略名單匯入 %d 名玩家。",
    TITLE_BANS = "QuietBan - 封鎖清單",
}

local own = translations[GetLocale and GetLocale() or "enUS"]
-- enUS is used as is: its own fallback would loop on a missing key.
NS.L = (own == translations.enUS) and own or setmetatable(own or {}, { __index = translations.enUS })
