--[[
	Credits panel (the Options panel's Credits button; original
	CAModCreditsPanel), showing #Amod_CreditsPanel_Credits.
]]

local panel

function HL2A.ShowCredits()
	if IsValid( panel ) then panel:Close() end

	panel = vgui.Create( "DFrame" )
	panel:SetTitle( language.GetPhrase( "Amod_OptionsPanel_Credits" ) )
	panel:SetSize( 360, 420 )
	panel:Center()
	panel:MakePopup()

	local text = panel:Add( "RichText" )
	text:Dock( FILL )
	text:InsertColorChange( 230, 230, 230, 255 )
	text:AppendText( HL2A.Spell( ( language.GetPhrase( "Amod_CreditsPanel_Credits" ):gsub( "\\n", "\n" ) ) ) )
	text.PerformLayout = function( self ) self:SetFontInternal( "Trebuchet18" ) end

	local music = panel:Add( "DButton" )
	music:Dock( BOTTOM )
	music:DockMargin( 0, 6, 0, 0 )
	music:SetTall( 24 )
	music:SetText( "Play the credits music" )
	music.DoClick = function() HL2A.Music.PlayPath( "music/credits.wav" ) end
end

concommand.Add( "OpenCreditsPanel", HL2A.ShowCredits, nil, "The Alone Mod credits" )
