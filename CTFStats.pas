//CTFStats 1.0 by Savage

uses database;

const
	DB_ID = 5;
	DB_NAME = '/home/shared_data/CTFStats.db';
	MSG_COLOR = $0080FF;
	TIME_SAVE_STATS = 60; //How often stats should be saved to database (in seconds)
	Skill_Update_Speed = 5;
	STEAM_VERIFICATION_TIME = 3;
	
var
	_SteamVerified: array[1..32] of Boolean;
	_SteamIDorHWID: array[1..32] of String;
	_Caps, _Kills, _Deaths, _Wins, _Loses, _CurrentSkills, _RememberCurrentSkills, _SteamVerificationTime: array[1..32] of Integer;
	_EliteList: TStringList;

function EscapeApostrophe(Source: String): String;
begin
	Result := ReplaceRegExpr('''', Source, '''''', False);
end;

function RoundUp(X: Single): Integer;
begin
	if (X - Trunc(X) <> 0) then
		Result := Trunc(X) + 1
	else
		Result := Trunc(X);
end;

function ShowTime(DaysPassed: TDateTime): String;
begin
	DaysPassed := Abs(DaysPassed);
	if Trunc(DaysPassed) > 0 then
		Result := IntToStr(Trunc(DaysPassed))+' '+iif(Trunc(DaysPassed) = 1, 'day', 'days')+', '+FormatDateTime('hh:nn:ss.zzz', DaysPassed)
	else
		if DaysPassed >= 1.0/24 then
			Result := FormatDateTime('hh:nn:ss.zzz', DaysPassed)
		else
			if DaysPassed >= 1.0/1440 then
				Result := FormatDateTime('nn:ss.zzz', DaysPassed)
			else
				if DaysPassed >= 1.0/86400 then
					Result := FormatDateTime('ss.zzz', DaysPassed)
				else
					if DaysPassed >= 1.0/86400000 then
						Result := FormatDateTime('zzz', DaysPassed)
					else
						Result := '000';
end;

procedure CheckCreatePlayerRecord(ID: Byte);
begin
	if Not DB_Query(DB_ID, 'SELECT Caps, Kills, Deaths, Wins, Loses, CurrentSkills FROM Stats WHERE Hwid = '''+EscapeApostrophe(Players[ID].HWID)+''' LIMIT 1;') then
		WriteLn('CheckCreatePlayerRecord Error1: '+DB_Error)
	else
		if Not DB_NextRow(DB_ID) then begin
			if Not DB_Update(DB_ID, 'INSERT INTO Stats(Name, Hwid) VALUES('''+EscapeApostrophe(Players[ID].Name)+''', '''+EscapeApostrophe(Players[ID].HWID)+''');') then
				WriteLn('CheckCreatePlayerRecord Error2: '+DB_Error);
		end else
			begin
				if Not DB_Update(DB_ID, 'UPDATE Stats SET Name = '''+EscapeApostrophe(Players[ID].Name)+''' WHERE Hwid = '''+EscapeApostrophe(Players[ID].HWID)+''';') then
					WriteLn('CheckCreatePlayerRecord Error3: '+DB_Error);
				
				_Caps[ID] := DB_GetLong(DB_ID, 0);
				_Kills[ID] := DB_GetLong(DB_ID, 1);
				_Deaths[ID] := DB_GetLong(DB_ID, 2);
				_Wins[ID] := DB_GetLong(DB_ID, 3);
				_Loses[ID] := DB_GetLong(DB_ID, 4);
				_CurrentSkills[ID] := DB_GetLong(DB_ID, 5);
				_RememberCurrentSkills[ID] := _CurrentSkills[ID];
			end;
				
	DB_FinishQuery(DB_ID);
	
	_SteamIDorHWID[ID] := Players[ID].HWID;
	Players[ID].WriteConsole('Connected to HWID stats', MSG_COLOR);
end;

procedure CheckCreatePlayerRecordSteam(ID: Byte);
begin
	if Not DB_Query(DB_ID, 'SELECT Caps, Kills, Deaths, Wins, Loses, CurrentSkills FROM Stats WHERE Hwid = '''+EscapeApostrophe(Players[ID].SteamIDString)+''' LIMIT 1;') then
		WriteLn('CheckCreatePlayerRecord Error1: '+DB_Error)
	else
		if Not DB_NextRow(DB_ID) then begin
			if Not DB_Update(DB_ID, 'INSERT INTO Stats(Name, Hwid) VALUES('''+EscapeApostrophe(Players[ID].Name)+''', '''+EscapeApostrophe(Players[ID].SteamIDString)+''');') then
				WriteLn('CheckCreatePlayerRecord Error2: '+DB_Error);
		end else
			begin
				if Not DB_Update(DB_ID, 'UPDATE Stats SET Name = '''+EscapeApostrophe(Players[ID].Name)+''' WHERE Hwid = '''+EscapeApostrophe(Players[ID].SteamIDString)+''';') then
					WriteLn('CheckCreatePlayerRecord Error3: '+DB_Error);
				
				_Caps[ID] := DB_GetLong(DB_ID, 0);
				_Kills[ID] := DB_GetLong(DB_ID, 1);
				_Deaths[ID] := DB_GetLong(DB_ID, 2);
				_Wins[ID] := DB_GetLong(DB_ID, 3);
				_Loses[ID] := DB_GetLong(DB_ID, 4);
				_CurrentSkills[ID] := DB_GetLong(DB_ID, 5);
				_RememberCurrentSkills[ID] := _CurrentSkills[ID];
			end;
				
	DB_FinishQuery(DB_ID);
	
	_SteamIDorHWID[ID] := Players[ID].SteamIDString;
	Players[ID].WriteConsole('Steam verification successful - Connected to SteamID stats', MSG_COLOR);
end;

procedure SavePlayerData(ID: Byte);
begin
	if Not DB_Update(DB_ID, 'UPDATE Stats SET Caps = '+IntToStr(_Caps[ID])+', Kills = '+IntToStr(_Kills[ID])+', Deaths = '+IntToStr(_Deaths[ID])+', Wins = '+IntToStr(_Wins[ID])+', Loses = '+IntToStr(_Loses[ID])+', CurrentSkills = '+IntToStr(_CurrentSkills[ID])+' WHERE Hwid = '''+EscapeApostrophe(_SteamIDorHWID[ID])+''';') then
		WriteLn('SavePlayerData Error1: '+DB_Error);
end;

procedure GetPlayerStatsName(ID: Byte; NameStr: String);
var
	i, j, TempNumber: Integer;
	TempTable: array[0..9] of TStringList;
	TempString, TempString2: String;
begin
	for i := 0 to 9 do
		TempTable[i] := File.CreateStringList;
	
	TempTable[0].Append('|Rank');//7
	TempTable[0].Append('|');
	
	TempTable[1].Append('|Id');//0
	TempTable[1].Append('');
	
	TempTable[2].Append('|Name');//1
	TempTable[2].Append('');
	
	TempTable[3].Append('|Caps');//8
	TempTable[3].Append('');
	
	TempTable[4].Append('|Kills');//2
	TempTable[4].Append('');
	
	TempTable[5].Append('|Deaths');//3
	TempTable[5].Append('');
	
	TempTable[6].Append('|K/D');
	TempTable[6].Append('');
	
	TempTable[7].Append('|Wins');//4
	TempTable[7].Append('');
	
	TempTable[8].Append('|Loses');//5
	TempTable[8].Append('');
	
	TempTable[9].Append('|Rating');//6
	TempTable[9].Append('');
	
	if Not DB_Query(DB_ID, 'SELECT Id, Name, Kills, Deaths, Wins, Loses, CurrentSkills, 1+(SELECT count(*) from Stats a WHERE a.CurrentSkills > b.CurrentSkills) as Position, Caps FROM Stats b WHERE Name = ''' + EscapeApostrophe(NameStr) + ''' ORDER BY Position LIMIT 5;') then
		WriteLn('GetPlayerStatsName Error1: '+DB_Error)
	else
		While DB_NextRow(DB_ID) Do Begin
			TempTable[0].Append('|'+DB_GetString(DB_ID, 7));//Position
			TempTable[1].Append('|'+DB_GetString(DB_ID, 0));//Id
			TempTable[2].Append('|'+DB_GetString(DB_ID, 1));//Name
			TempTable[3].Append('|'+DB_GetString(DB_ID, 8));//Caps
			
			TempString := DB_GetString(DB_ID, 2);//Kills
			TempTable[4].Append('|'+TempString);//Kills
			
			TempString2 := DB_GetString(DB_ID, 3);//Deaths
			TempTable[5].Append('|'+TempString2);//Deaths
			
			TempTable[6].Append('|'+FormatFloat('0.00', StrToFloat(TempString)/IIF(StrToFloat(TempString2) = 0, 1, StrToFloat(TempString2))));//K/D
			TempTable[7].Append('|'+DB_GetString(DB_ID, 4));//Wins
			TempTable[8].Append('|'+DB_GetString(DB_ID, 5));//Loses
			TempTable[9].Append('|'+DB_GetString(DB_ID, 6));//CurrentSkills
		end;
	
	for j := 0 to 9 do begin
		
		TempNumber := 0;
		
		for i := 0 to TempTable[j].Count-1 do
			if length(TempTable[j][i]) > TempNumber then
				TempNumber := length(TempTable[j][i]);
		
		for i := 0 to TempTable[j].Count-1 do begin
			TempString := TempTable[j][i];
			While length(TempString) < TempNumber do
				if i = 1 then
					Insert('-', TempString, Length(TempString)+1)
				else
					Insert(' ', TempString, Length(TempString)+1);
			TempTable[j][i] := TempString;
		end;
		
	end;
	
	TempNumber := Length(TempTable[0][0])+Length(TempTable[1][0])+Length(TempTable[2][0])+Length(TempTable[3][0])+Length(TempTable[4][0])+Length(TempTable[5][0])+Length(TempTable[6][0])+Length(TempTable[7][0])+Length(TempTable[8][0])+Length(TempTable[9][0])+1;
	
	TempString := '-';
	While length(TempString) < TempNumber do
		Insert('-', TempString, Length(TempString)+1);
	Players[ID].WriteConsole(TempString, MSG_COLOR);
	
	for i := 0 to TempTable[0].Count-1 do
		Players[ID].WriteConsole(TempTable[0][i]+TempTable[1][i]+TempTable[2][i]+TempTable[3][i]+TempTable[4][i]+TempTable[5][i]+TempTable[6][i]+TempTable[7][i]+TempTable[8][i]+TempTable[9][i]+'|', MSG_COLOR);
		
	Players[ID].WriteConsole(TempString, MSG_COLOR);
	
	DB_FinishQuery(DB_ID);
	
	for i := 0 to 9 do
		TempTable[i].Free;
end;

procedure GetPlayerStatsHW(ID: Byte; HWStr: String);
var
	i, j, TempNumber: Integer;
	TempTable: array[0..9] of TStringList;
	TempString, TempString2: String;
begin
	for i := 0 to 9 do
		TempTable[i] := File.CreateStringList;
	
	TempTable[0].Append('|Rank');//7
	TempTable[0].Append('|');
	
	TempTable[1].Append('|Id');//0
	TempTable[1].Append('');
	
	TempTable[2].Append('|Name');//1
	TempTable[2].Append('');
	
	TempTable[3].Append('|Caps');//8
	TempTable[3].Append('');
	
	TempTable[4].Append('|Kills');//2
	TempTable[4].Append('');
	
	TempTable[5].Append('|Deaths');//3
	TempTable[5].Append('');
	
	TempTable[6].Append('|K/D');
	TempTable[6].Append('');
	
	TempTable[7].Append('|Wins');//4
	TempTable[7].Append('');
	
	TempTable[8].Append('|Loses');//5
	TempTable[8].Append('');
	
	TempTable[9].Append('|Rating');//6
	TempTable[9].Append('');
	
	if Not DB_Query(DB_ID, 'SELECT Id, Name, Kills, Deaths, Wins, Loses, CurrentSkills, 1+(SELECT count(*) from Stats a WHERE a.CurrentSkills > b.CurrentSkills) as Position, Caps FROM Stats b WHERE Hwid = ''' + EscapeApostrophe(HWStr) + ''' LIMIT 1;') then
		WriteLn('GetPlayerStatsHW Error1: '+DB_Error)
	else
		While DB_NextRow(DB_ID) Do Begin
			TempTable[0].Append('|'+DB_GetString(DB_ID, 7));//Position
			TempTable[1].Append('|'+DB_GetString(DB_ID, 0));//Id
			TempTable[2].Append('|'+DB_GetString(DB_ID, 1));//Name
			TempTable[3].Append('|'+DB_GetString(DB_ID, 8));//Caps
			
			TempString := DB_GetString(DB_ID, 2);//Kills
			TempTable[4].Append('|'+TempString);//Kills
			
			TempString2 := DB_GetString(DB_ID, 3);//Deaths
			TempTable[5].Append('|'+TempString2);//Deaths
			
			TempTable[6].Append('|'+FormatFloat('0.00', StrToFloat(TempString)/IIF(StrToFloat(TempString2) = 0, 1, StrToFloat(TempString2))));//K/D
			TempTable[7].Append('|'+DB_GetString(DB_ID, 4));//Wins
			TempTable[8].Append('|'+DB_GetString(DB_ID, 5));//Loses
			TempTable[9].Append('|'+DB_GetString(DB_ID, 6));//CurrentSkills
		end;
	
	for j := 0 to 9 do begin
		
		TempNumber := 0;
		
		for i := 0 to TempTable[j].Count-1 do
			if length(TempTable[j][i]) > TempNumber then
				TempNumber := length(TempTable[j][i]);
		
		for i := 0 to TempTable[j].Count-1 do begin
			TempString := TempTable[j][i];
			While length(TempString) < TempNumber do
				if i = 1 then
					Insert('-', TempString, Length(TempString)+1)
				else
					Insert(' ', TempString, Length(TempString)+1);
			TempTable[j][i] := TempString;
		end;
		
	end;
	
	TempNumber := Length(TempTable[0][0])+Length(TempTable[1][0])+Length(TempTable[2][0])+Length(TempTable[3][0])+Length(TempTable[4][0])+Length(TempTable[5][0])+Length(TempTable[6][0])+Length(TempTable[7][0])+Length(TempTable[8][0])+Length(TempTable[9][0])+1;
	
	TempString := '-';
	While length(TempString) < TempNumber do
		Insert('-', TempString, Length(TempString)+1);
	Players[ID].WriteConsole(TempString, MSG_COLOR);
	
	for i := 0 to TempTable[0].Count-1 do
		Players[ID].WriteConsole(TempTable[0][i]+TempTable[1][i]+TempTable[2][i]+TempTable[3][i]+TempTable[4][i]+TempTable[5][i]+TempTable[6][i]+TempTable[7][i]+TempTable[8][i]+TempTable[9][i]+'|', MSG_COLOR);
		
	Players[ID].WriteConsole(TempString, MSG_COLOR);
	
	DB_FinishQuery(DB_ID);
	
	for i := 0 to 9 do
		TempTable[i].Free;
end;

procedure GenerateEliteList;
var
	i, j, TempNumber: Integer;
	TempTable: array[0..9] of TStringList;
	TempString, TempString2: String;
begin
	_EliteList.Clear;
	
	for i := 0 to 9 do
		TempTable[i] := File.CreateStringList;
	
	TempTable[0].Append('|Rank');
	TempTable[0].Append('|');
	
	TempTable[1].Append('|Id');//0
	TempTable[1].Append('');
	
	TempTable[2].Append('|Name');//1
	TempTable[2].Append('');
	
	TempTable[3].Append('|Caps');//7
	TempTable[3].Append('');
	
	TempTable[4].Append('|Kills');//2
	TempTable[4].Append('');
	
	TempTable[5].Append('|Deaths');//3
	TempTable[5].Append('');
	
	TempTable[6].Append('|K/D');
	TempTable[6].Append('');
	
	TempTable[7].Append('|Wins');//4
	TempTable[7].Append('');
	
	TempTable[8].Append('|Loses');//5
	TempTable[8].Append('');
	
	TempTable[9].Append('|Rating');//6
	TempTable[9].Append('');
	
	if Not DB_Query(DB_ID, 'SELECT Id, Name, Kills, Deaths, Wins, Loses, CurrentSkills, Caps FROM Stats ORDER BY CurrentSkills DESC LIMIT 20;') then
		WriteLn('GenerateEliteList Error1: '+DB_Error)
	else
		While DB_NextRow(DB_ID) Do Begin
			Inc(TempNumber, 1);
			
			TempTable[0].Append('|'+IntToStr(TempNumber));
			TempTable[1].Append('|'+DB_GetString(DB_ID, 0));//Id
			TempTable[2].Append('|'+DB_GetString(DB_ID, 1));//Name
			TempTable[3].Append('|'+DB_GetString(DB_ID, 7));//Caps
			
			TempString := DB_GetString(DB_ID, 2);//Kills
			TempTable[4].Append('|'+TempString);//Kills
			
			TempString2 := DB_GetString(DB_ID, 3);//Deaths
			TempTable[5].Append('|'+TempString2);//Deaths
			
			TempTable[6].Append('|'+FormatFloat('0.00', StrToFloat(TempString)/IIF(StrToFloat(TempString2) = 0, 1, StrToFloat(TempString2))));//K/D
			TempTable[7].Append('|'+DB_GetString(DB_ID, 4));//Wins
			TempTable[8].Append('|'+DB_GetString(DB_ID, 5));//Loses
			TempTable[9].Append('|'+DB_GetString(DB_ID, 6));//CurrentSkills
		end;
	
	for j := 0 to 9 do begin
		
		TempNumber := 0;
		
		for i := 0 to TempTable[j].Count-1 do
			if length(TempTable[j][i]) > TempNumber then
				TempNumber := length(TempTable[j][i]);
		
		for i := 0 to TempTable[j].Count-1 do begin
			TempString := TempTable[j][i];
			While length(TempString) < TempNumber do
				if i = 1 then
					Insert('-', TempString, Length(TempString)+1)
				else
					Insert(' ', TempString, Length(TempString)+1);
			TempTable[j][i] := TempString;
		end;
		
	end;
	
	TempNumber := Length(TempTable[0][0])+Length(TempTable[1][0])+Length(TempTable[2][0])+Length(TempTable[3][0])+Length(TempTable[4][0])+Length(TempTable[5][0])+Length(TempTable[6][0])+Length(TempTable[7][0])+Length(TempTable[8][0])+Length(TempTable[9][0])+1;
	
	TempString := '-';
	While length(TempString) < TempNumber do
		Insert('-', TempString, Length(TempString)+1);
	_EliteList.Append(TempString);
	
	for i := 0 to TempTable[0].Count-1 do
		_EliteList.Append(TempTable[0][i]+TempTable[1][i]+TempTable[2][i]+TempTable[3][i]+TempTable[4][i]+TempTable[5][i]+TempTable[6][i]+TempTable[7][i]+TempTable[8][i]+TempTable[9][i]+'|');
		
	_EliteList.Append(TempString);
	
	DB_FinishQuery(DB_ID);
	
	for i := 0 to 9 do
		TempTable[i].Free;
end;

procedure ShowPlayers(ID: Byte);
var
	i, j, TempNumber: ShortInt;
	TopNameAlpha, TopNameBravo, TopAmountAlpha, TopAmountBravo: TStringList;
	TempTable: array[0..3] of TStringList;
	TempString: String;
begin
	TopNameAlpha := File.CreateStringList;
	TopNameBravo := File.CreateStringList;
	TopAmountAlpha := File.CreateStringList;
	TopAmountBravo := File.CreateStringList;
	
	if Game.Teams[1].Count <> 0 then
		for i := 0 to Game.Teams[1].Count-1 do begin
			TopNameAlpha.Append(Game.Teams[1].Player[i].Name);
			TopAmountAlpha.Append(IntToStr(_CurrentSkills[Game.Teams[1].Player[i].ID]));
			
			for j := i downto 1 do
				if StrToInt(TopAmountAlpha[j]) > StrToInt(TopAmountAlpha[j-1]) then begin
					TopNameAlpha.Exchange(j-1, j);
					TopAmountAlpha.Exchange(j-1, j);
				end else break;
		end;
	
	if Game.Teams[2].Count <> 0 then
		for i := 0 to Game.Teams[2].Count-1 do begin
			TopNameBravo.Append(Game.Teams[2].Player[i].Name);
			TopAmountBravo.Append(IntToStr(_CurrentSkills[Game.Teams[2].Player[i].ID]));
			
			for j := i downto 1 do
				if StrToInt(TopAmountBravo[j]) > StrToInt(TopAmountBravo[j-1]) then begin
					TopNameBravo.Exchange(j-1, j);
					TopAmountBravo.Exchange(j-1, j);
				end else break;
		end;
	
	for i := 0 to 3 do
		TempTable[i] := File.CreateStringList;
		
	TempTable[0].Append('|Alpha Players');
	TempTable[0].Append('|');
	
	TempTable[1].Append('|Alpha Rating');
	TempTable[1].Append('');
	
	TempTable[2].Append('|Bravo Rating');
	TempTable[2].Append('');
	
	TempTable[3].Append('|Bravo Players');
	TempTable[3].Append('');
	
	if TopNameAlpha.Count > TopNameBravo.Count then
		TempNumber := TopNameAlpha.Count-1
	else
		TempNumber := TopNameBravo.Count-1;
	
	for i := 0 to TempNumber do begin
		
		if i > TopNameAlpha.Count-1 then
			TempTable[0].Append('|')
		else
			TempTable[0].Append('|'+TopNameAlpha[i]);
			
		if i > TopNameAlpha.Count-1 then
			TempTable[1].Append('|')
		else
			TempTable[1].Append('|'+TopAmountAlpha[i]);
			
		if i > TopNameBravo.Count-1 then
			TempTable[2].Append('|')
		else
			TempTable[2].Append('|'+TopAmountBravo[i]);
			
		if i > TopNameBravo.Count-1 then
			TempTable[3].Append('|')
		else
			TempTable[3].Append('|'+TopNameBravo[i]);
		
	end;
	
	for j := 0 to 3 do begin
		
		TempNumber := 0;
		
		for i := 0 to TempTable[j].Count-1 do
			if length(TempTable[j][i]) > TempNumber then
				TempNumber := length(TempTable[j][i]);
		
		for i := 0 to TempTable[j].Count-1 do begin
			TempString := TempTable[j][i];
			While length(TempString) < TempNumber do
				if i = 1 then
					Insert('-', TempString, Length(TempString)+1)
				else
					Insert(' ', TempString, Length(TempString)+1);
			TempTable[j][i] := TempString;
		end;
		
	end;
	
	TempNumber := Length(TempTable[0][0])+Length(TempTable[1][0])+Length(TempTable[2][0])+Length(TempTable[3][0])+1;
	
	TempString := '-';
	While length(TempString) < TempNumber do
		Insert('-', TempString, Length(TempString)+1);
	Players[ID].WriteConsole(TempString, MSG_COLOR);
	
	for i := 0 to TempTable[0].Count-1 do
		Players[ID].WriteConsole(TempTable[0][i]+TempTable[1][i]+TempTable[2][i]+TempTable[3][i]+'|', MSG_COLOR);
		
	Players[ID].WriteConsole(TempString, MSG_COLOR);
	
	for i := 0 to 3 do
		TempTable[i].Free;
	
	TopNameAlpha.Free;
	TopNameBravo.Free;
	TopAmountAlpha.Free;
	TopAmountBravo.Free;
end;

//Events Handling/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

procedure OnPlayerSpeak(Player: TActivePlayer; Text: string);
var
	TempInt, SumAlpha, SumBravo, AvgAlpha, AvgBravo: Integer;
begin
	if Text = '!stats' then
		GetPlayerStatsHW(Player.ID, _SteamIDorHWID[Player.ID]);
	
	if Text = '!rstats' then begin
		Player.WriteConsole('HWID: '+Player.HWID, MSG_COLOR);
		Player.WriteConsole('SteamID: '+Player.SteamIDString, MSG_COLOR);
		Player.WriteConsole('Caps: '+IntToStr(_Caps[Player.ID]), MSG_COLOR);
		Player.WriteConsole('Kills: '+IntToStr(_Kills[Player.ID]), MSG_COLOR);
		Player.WriteConsole('Deaths: '+IntToStr(_Deaths[Player.ID]), MSG_COLOR);
		Player.WriteConsole('K/D: '+FormatFloat('0.00', _Kills[Player.ID]*1.0/IIF(_Deaths[Player.ID] = 0, 1, _Deaths[Player.ID])), MSG_COLOR);
		Player.WriteConsole('Wins: '+IntToStr(_Wins[Player.ID]), MSG_COLOR);
		Player.WriteConsole('Loses: '+IntToStr(_Loses[Player.ID]), MSG_COLOR);
		Player.WriteConsole('Rating: '+IntToStr(_CurrentSkills[Player.ID]), MSG_COLOR);
	end;
	
	if (Copy(Text, 1, 7) = '!stats ') and (Copy(Text, 8, Length(Text)) <> nil) then begin
		Player.WriteConsole('Best 5 players with name "'+Copy(Text, 8, Length(Text))+'"', MSG_COLOR);
		GetPlayerStatsName(Player.ID, Copy(Text, 8, Length(Text)));
	end;
	
	if (Copy(Text, 1, 9) = '!statsid ') and (Copy(Text, 10, Length(Text)) <> nil) then begin
		Try
			TempInt := StrToInt(Copy(Text, 10, Length(Text)));
		Except
			Player.WriteConsole('Invalid integer', $FF0000);
		end;
		
		if (TempInt <= 32) and (TempInt >= 1) then begin
			if (Players[TempInt].Active) and (Players[TempInt].Human) and (_SteamIDorHWID[TempInt] <> '') then
				GetPlayerStatsHW(Player.ID, _SteamIDorHWID[TempInt])
			else
				Player.WriteConsole('Player with ID "'+Copy(Text, 10, Length(Text))+'" doesn''t exists', $FF0000);
		end else Player.WriteConsole('ID has to be from 1 to 32', $FF0000);
	end;
	
	if (Text = '!elite') or (Text = '!top') then begin
		Player.WriteConsole('Best =Midgard CTF Players', MSG_COLOR);
		for TempInt := 0 to _EliteList.Count-1 do
			if TempInt = 3 then
				Player.WriteConsole(_EliteList[TempInt], $FFD700)
			else
				if TempInt = 4 then
					Player.WriteConsole(_EliteList[TempInt], $C0C0C0)
				else
					if TempInt = 5 then
						Player.WriteConsole(_EliteList[TempInt], $F4A460)
					else
						Player.WriteConsole(_EliteList[TempInt], MSG_COLOR);
	end;
	
	if Text = '!players' then begin
		ShowPlayers(Player.ID);
		
		if Game.Teams[1].Count <> 0 then begin
			for TempInt := 0 to Game.Teams[1].Count-1 do
				Inc(SumAlpha, _CurrentSkills[Game.Teams[1].Player[TempInt].ID]);
		
			AvgAlpha := SumAlpha div Game.Teams[1].Count;
		end;
		
		if Game.Teams[2].Count <> 0 then begin
			for TempInt := 0 to Game.Teams[2].Count-1 do
				Inc(SumBravo, _CurrentSkills[Game.Teams[2].Player[TempInt].ID]);
		
			AvgBravo := SumBravo div Game.Teams[2].Count;
		end;
		
		if SumAlpha = SumBravo then
			Player.WriteConsole('Sum: '+IntToStr(SumAlpha)+'='+IntToStr(SumBravo), MSG_COLOR)
		else
			if SumAlpha > SumBravo then
				Player.WriteConsole('Sum: '+IntToStr(SumAlpha)+'>'+IntToStr(SumBravo), $FF0000)
			else
				Player.WriteConsole('Sum: '+IntToStr(SumAlpha)+'<'+IntToStr(SumBravo), $0000FF);
		
		if AvgAlpha = AvgBravo then
			Player.WriteConsole('Avg: '+IntToStr(AvgAlpha)+'='+IntToStr(AvgBravo), MSG_COLOR)
		else
			if AvgAlpha > AvgBravo then
				Player.WriteConsole('Avg: '+IntToStr(AvgAlpha)+'>'+IntToStr(AvgBravo), $FF0000)
			else
				Player.WriteConsole('Avg: '+IntToStr(AvgAlpha)+'<'+IntToStr(AvgBravo), $0000FF);
	end;
end;

function OnPlayerCommand(Player: TActivePlayer; Command: String): Boolean;
var
	TempInt, SumAlpha, SumBravo, AvgAlpha, AvgBravo: Integer;
begin
Result := False;
	
	if Command = '/stats' then
		GetPlayerStatsHW(Player.ID, _SteamIDorHWID[Player.ID]);
	
	if Command = '/rstats' then begin
		Player.WriteConsole('HWID: '+Player.HWID, MSG_COLOR);
		Player.WriteConsole('SteamID: '+Player.SteamIDString, MSG_COLOR);
		Player.WriteConsole('Caps: '+IntToStr(_Caps[Player.ID]), MSG_COLOR);
		Player.WriteConsole('Kills: '+IntToStr(_Kills[Player.ID]), MSG_COLOR);
		Player.WriteConsole('Deaths: '+IntToStr(_Deaths[Player.ID]), MSG_COLOR);
		Player.WriteConsole('K/D: '+FormatFloat('0.00', _Kills[Player.ID]*1.0/IIF(_Deaths[Player.ID] = 0, 1, _Deaths[Player.ID])), MSG_COLOR);
		Player.WriteConsole('Wins: '+IntToStr(_Wins[Player.ID]), MSG_COLOR);
		Player.WriteConsole('Loses: '+IntToStr(_Loses[Player.ID]), MSG_COLOR);
		Player.WriteConsole('Rating: '+IntToStr(_CurrentSkills[Player.ID]), MSG_COLOR);
	end;
	
	if (Copy(Command, 1, 7) = '/stats ') and (Copy(Command, 8, Length(Command)) <> nil) then begin
		Player.WriteConsole('Best 5 players with name "'+Copy(Command, 8, Length(Command))+'"', MSG_COLOR);
		GetPlayerStatsName(Player.ID, Copy(Command, 8, Length(Command)));
	end;
	
	if (Copy(Command, 1, 9) = '/statsid ') and (Copy(Command, 10, Length(Command)) <> nil) then begin
		Try
			TempInt := StrToInt(Copy(Command, 10, Length(Command)));
		Except
			Player.WriteConsole('Invalid integer', $FF0000);
		end;
		
		if (TempInt <= 32) and (TempInt >= 1) then begin
			if (Players[TempInt].Active) and (Players[TempInt].Human) and (_SteamIDorHWID[TempInt] <> '') then
				GetPlayerStatsHW(Player.ID, _SteamIDorHWID[TempInt])
			else
				Player.WriteConsole('Player with ID "'+Copy(Command, 10, Length(Command))+'" doesn''t exists', $FF0000);
		end else Player.WriteConsole('ID has to be from 1 to 32', $FF0000);
	end;
	
	if (Command = '/elite') or (Command = '/top') then begin
		Player.WriteConsole('Best =Midgard CTF Players', MSG_COLOR);
		for TempInt := 0 to _EliteList.Count-1 do
			if TempInt = 3 then
				Player.WriteConsole(_EliteList[TempInt], $FFD700)
			else
				if TempInt = 4 then
					Player.WriteConsole(_EliteList[TempInt], $C0C0C0)
				else
					if TempInt = 5 then
						Player.WriteConsole(_EliteList[TempInt], $F4A460)
					else
						Player.WriteConsole(_EliteList[TempInt], MSG_COLOR);
	end;
	
	if Command = '/players' then begin
		ShowPlayers(Player.ID);
		
		if Game.Teams[1].Count <> 0 then begin
			for TempInt := 0 to Game.Teams[1].Count-1 do
				Inc(SumAlpha, _CurrentSkills[Game.Teams[1].Player[TempInt].ID]);
		
			AvgAlpha := SumAlpha div Game.Teams[1].Count;
		end;
		
		if Game.Teams[2].Count <> 0 then begin
			for TempInt := 0 to Game.Teams[2].Count-1 do
				Inc(SumBravo, _CurrentSkills[Game.Teams[2].Player[TempInt].ID]);
		
			AvgBravo := SumBravo div Game.Teams[2].Count;
		end;
		
		if SumAlpha = SumBravo then
			Player.WriteConsole('Sum: '+IntToStr(SumAlpha)+'='+IntToStr(SumBravo), MSG_COLOR)
		else
			if SumAlpha > SumBravo then
				Player.WriteConsole('Sum: '+IntToStr(SumAlpha)+'>'+IntToStr(SumBravo), $FF0000)
			else
				Player.WriteConsole('Sum: '+IntToStr(SumAlpha)+'<'+IntToStr(SumBravo), $0000FF);
		
		if AvgAlpha = AvgBravo then
			Player.WriteConsole('Avg: '+IntToStr(AvgAlpha)+'='+IntToStr(AvgBravo), MSG_COLOR)
		else
			if AvgAlpha > AvgBravo then
				Player.WriteConsole('Avg: '+IntToStr(AvgAlpha)+'>'+IntToStr(AvgBravo), $FF0000)
			else
				Player.WriteConsole('Avg: '+IntToStr(AvgAlpha)+'<'+IntToStr(AvgBravo), $0000FF);
	end;
end;

procedure OnFlagScore(Player: TActivePlayer; Flag: TActiveFlag; Team: Byte);
begin
	if (Game.NumPlayers-Game.Spectators > 3) and (Player.Human) then begin
		Inc(_Caps[Player.ID], 1);
		Inc(_CurrentSkills[Player.ID], 100);
		Player.WriteConsole('You''ve gained 100 rating points for scoring', MSG_COLOR);
	end;
end;

procedure OnPlayerKill(Killer, Victim: TActivePlayer; BulletId: Byte);
var
	RawPoints, NewDivider: Single;
	Points, Points2, NewMax: Integer;
begin
	if (Killer.Human) and (Victim.Human) and (Killer.ID<>Victim.ID) then begin
		
		Inc(_Kills[Killer.ID], 1);
		Inc(_Deaths[Victim.ID], 1);
		
		if (_CurrentSkills[Killer.ID] <= Skill_Update_Speed*10000/2) and (_CurrentSkills[Victim.ID] <= Skill_Update_Speed*10000/2) then begin
			
			Points := RoundUp((Skill_Update_Speed*10000-_CurrentSkills[Killer.ID])*1.0/100/Skill_Update_Speed);
			_CurrentSkills[Killer.ID] := _CurrentSkills[Killer.ID] + Points;
			Killer.WorldText(Victim.ID, '+'+IntToStr(Points), 120, $00FF00, 0.05, Victim.X, Victim.Y);
			
			Points := RoundUp(_CurrentSkills[Victim.ID]*1.0/100/Skill_Update_Speed);
			_CurrentSkills[Victim.ID] := _CurrentSkills[Victim.ID] - Points;
			Victim.WorldText(Victim.ID, '-'+IntToStr(Points), 120, $FF0000, 0.05, Victim.X, Victim.Y);
			
		end else
			if _CurrentSkills[Killer.ID] >= _CurrentSkills[Victim.ID] then begin
				
				RawPoints := (Skill_Update_Speed*10000-_CurrentSkills[Killer.ID])*1.0/100/Skill_Update_Speed;
				Points := RoundUp(RawPoints);
				
				if _CurrentSkills[Killer.ID] >= Skill_Update_Speed*10000 then begin
					Inc(_CurrentSkills[Killer.ID], 1);
					Killer.WorldText(Victim.ID, '+1', 120, $00FF00, 0.05, Victim.X, Victim.Y);
				end else
					begin
						_CurrentSkills[Killer.ID] := _CurrentSkills[Killer.ID] + Points;
						Killer.WorldText(Victim.ID, '+'+IntToStr(Points), 120, $00FF00, 0.05, Victim.X, Victim.Y);
					end;
				
				if _CurrentSkills[Killer.ID] >= Skill_Update_Speed*10000 then begin
					if _CurrentSkills[Victim.ID] = 0 then
						Victim.WorldText(Victim.ID, '-0', 120, $FF0000, 0.05, Victim.X, Victim.Y)
					else begin
						Dec(_CurrentSkills[Victim.ID], 1);
						Victim.WorldText(Victim.ID, '-1', 120, $FF0000, 0.05, Victim.X, Victim.Y);
					end;
				end else
					begin
						Points := RoundUp(_CurrentSkills[Victim.ID]/(_CurrentSkills[Killer.ID]*1.0/RawPoints));
						_CurrentSkills[Victim.ID] := _CurrentSkills[Victim.ID] - Points;
						Victim.WorldText(Victim.ID, '-'+IntToStr(Points), 120, $FF0000, 0.05, Victim.X, Victim.Y);
					end;
				
			end else
				begin
					
					NewMax := _CurrentSkills[Victim.ID]*2;
					NewDivider := NewMax/100.0;
					
					Points := RoundUp((NewMax-_CurrentSkills[Killer.ID])/NewDivider);
					_CurrentSkills[Killer.ID] := _CurrentSkills[Killer.ID] + Points;
					Killer.WorldText(Victim.ID, '+'+IntToStr(Points), 120, $00FF00, 0.05, Victim.X, Victim.Y);
					
					Points2 := RoundUp(_CurrentSkills[Victim.ID]*1.0/100/Skill_Update_Speed);
					
					if Points > Points2 then begin
						_CurrentSkills[Victim.ID] := _CurrentSkills[Victim.ID] - Points2;
						Victim.WorldText(Victim.ID, '-'+IntToStr(Points2), 120, $FF0000, 0.05, Victim.X, Victim.Y);
					end else
						begin
							_CurrentSkills[Victim.ID] := _CurrentSkills[Victim.ID] - Points;
							Victim.WorldText(Victim.ID, '-'+IntToStr(Points), 120, $FF0000, 0.05, Victim.X, Victim.Y);
						end;
					
				end;
		
	end;
end;

procedure OnBeforeMapChange(Next: String);
var
	TimeStart: TDateTime;
	i: Byte;
begin
	if Game.Teams[1].Score > Game.Teams[2].Score then
		for i := 1 to 32 do
			if (Players[i].Active) and (Players[i].Human) then
				if Players[i].Team = 1 then
					Inc(_Wins[i], 1)
				else
					if Players[i].Team = 2 then
						Inc(_Loses[i], 1);
						
	if Game.Teams[2].Score > Game.Teams[1].Score then
		for i := 1 to 32 do
			if (Players[i].Active) and (Players[i].Human) then
				if Players[i].Team = 2 then
					Inc(_Wins[i], 1)
				else
					if Players[i].Team = 1 then
						Inc(_Loses[i], 1);
	
	DB_Update(DB_ID, 'BEGIN TRANSACTION;');
		for i := 1 to 32 do
			if (Players[i].Active) and (Players[i].Human) and (_SteamIDorHWID[i] <> '') then begin
				if Not DB_Update(DB_ID, 'UPDATE Stats SET Caps = '+IntToStr(_Caps[i])+', Kills = '+IntToStr(_Kills[i])+', Deaths = '+IntToStr(_Deaths[i])+', Wins = '+IntToStr(_Wins[i])+', Loses = '+IntToStr(_Loses[i])+', CurrentSkills = '+IntToStr(_CurrentSkills[i])+' WHERE Hwid = '''+EscapeApostrophe(_SteamIDorHWID[i])+''';') then
					WriteLn('SavePlayerData Error3: '+DB_Error);
				
				if _RememberCurrentSkills[i] = _CurrentSkills[i] then
					Players[i].WriteConsole('Rating map summary: '+IntToStr(_RememberCurrentSkills[i])+' -> '+IntToStr(_CurrentSkills[i])+'(+0)', MSG_COLOR)
				else
					if _RememberCurrentSkills[i] > _CurrentSkills[i] then
						Players[i].WriteConsole('Rating map summary: '+IntToStr(_RememberCurrentSkills[i])+' -> '+IntToStr(_CurrentSkills[i])+'('+IntToStr(_CurrentSkills[i]-_RememberCurrentSkills[i])+')', $FF0000)
					else
						Players[i].WriteConsole('Rating map summary: '+IntToStr(_RememberCurrentSkills[i])+' -> '+IntToStr(_CurrentSkills[i])+'(+'+IntToStr(_CurrentSkills[i]-_RememberCurrentSkills[i])+')', $00FF00);
						
				_RememberCurrentSkills[i] := _CurrentSkills[i];
			end;
	DB_Update(DB_ID, 'COMMIT;');
	
	WriteLn('Generating elite list...');
	TimeStart := Now;
	GenerateEliteList;
	WriteLn('Done in '+ShowTime(Now - TimeStart));
end;

procedure Clock(Ticks: Integer);
var
	i: Byte;
begin
	if Ticks mod (60*TIME_SAVE_STATS) = 0 then begin
		DB_Update(DB_ID, 'BEGIN TRANSACTION;');
		
		for i := 1 to 32 do
			if (Players[i].Active) and (Players[i].Human) and (_SteamIDorHWID[i] <> '') then
				if Not DB_Update(DB_ID, 'UPDATE Stats SET Caps = '+IntToStr(_Caps[i])+', Kills = '+IntToStr(_Kills[i])+', Deaths = '+IntToStr(_Deaths[i])+', Wins = '+IntToStr(_Wins[i])+', Loses = '+IntToStr(_Loses[i])+', CurrentSkills = '+IntToStr(_CurrentSkills[i])+' WHERE Hwid = '''+EscapeApostrophe(_SteamIDorHWID[i])+''';') then
					WriteLn('SavePlayerData Error2: '+DB_Error);
		
		DB_Update(DB_ID, 'COMMIT;');
	end;
	
	for i := 1 to 32 do
		if Players[i].Active then
			if _SteamVerificationTime[i] > 0 then begin
				Dec(_SteamVerificationTime[i], 1);
				
				if _SteamVerificationTime[i] = 0 then
					if _SteamVerified[i] then
						CheckCreatePlayerRecordSteam(i)
					else
						CheckCreatePlayerRecord(i);
			end;
end;

procedure OnJoin(Player: TActivePlayer; Team: TTeam);
begin
	_SteamVerified[Player.ID] := False;//If somehow OnSteamAuth executes after OnLeave
	if Player.Human then begin
		Player.WriteConsole('Connecting to stats... - Waiting for Steam verification...', MSG_COLOR);
		_SteamVerificationTime[Player.ID] := STEAM_VERIFICATION_TIME;
	end;
end;

function OnSteamAuth(PlayerId: Byte; AuthState: Byte): Byte;
begin
	if AuthState = 0 then
		_SteamVerified[PlayerId] := True;
end;

procedure OnLeave(Player: TActivePlayer; Kicked: Boolean);
begin
	if (Player.Human) and (_SteamIDorHWID[Player.ID] <> '') then
		SavePlayerData(Player.ID);
	_Caps[Player.ID] := 0;
	_Kills[Player.ID] := 0;
	_Deaths[Player.ID] := 0;
	_Wins[Player.ID] := 0;
	_Loses[Player.ID] := 0;
	_CurrentSkills[Player.ID] := 0;
	
	_SteamVerified[Player.ID] := False;
	_SteamIDorHWID[Player.ID] := '';
	_SteamVerificationTime[Player.ID] := 0;
end;

procedure Init;
var
	i: Byte;
	DBFile: TFileStream;
	Query: String;
begin
	if not File.Exists(DB_NAME) then begin
		DBFile := File.CreateFileStream;
		DBFile.SaveToFile(DB_NAME);
		DBFile.Free;
		WriteLn('Database "'+DB_NAME+'" has been created');
		if DatabaseOpen(DB_ID, DB_NAME, '', '', DB_Plugin_SQLite) then begin
			Query := 'CREATE TABLE Stats(Id INTEGER PRIMARY KEY,';
			Query := Query+'Name TEXT,';
			Query := Query+'Hwid TEXT UNIQUE,';
			Query := Query+'Caps INTEGER DEFAULT 0,';
			Query := Query+'Kills INTEGER DEFAULT 0,';
			Query := Query+'Deaths INTEGER DEFAULT 0,';
			Query := Query+'Wins INTEGER DEFAULT 0,';
			Query := Query+'Loses INTEGER DEFAULT 0,';
			Query := Query+'CurrentSkills INTEGER DEFAULT 0);';
			DatabaseUpdate(DB_ID, Query);
		end;
	end else
		DatabaseOpen(DB_ID, DB_NAME, '', '', DB_Plugin_SQLite);
		
	_EliteList := File.CreateStringList;
	GenerateEliteList;
		
	for i := 1 to 32 do begin
		Players[i].OnSpeak := @OnPlayerSpeak;
		Players[i].OnCommand := @OnPlayerCommand;
		Players[i].OnKill := @OnPlayerKill;
		Players[i].OnFlagScore := @OnFlagScore;
		
		if (Players[i].Active) and (Players[i].Human) then begin
			Players[i].WriteConsole('CTFStats script recompiled - Please rejoin', MSG_COLOR);
			Players[i].Kick(TKickSilent);
		end;
	end;
	
	Game.OnClockTick := @Clock;
	Map.OnBeforeMapChange := @OnBeforeMapChange;
	Game.OnJoin := @OnJoin;
	Game.OnSteamAuth := @OnSteamAuth;
	Game.OnLeave := @OnLeave;
end;

begin
	WriteLn('CTFStats 1.0 by Savage');
    Init;
end.