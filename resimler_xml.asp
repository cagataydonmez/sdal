<%
Set bagg = Server.CreateObject("ADODB.Connection")
bagg.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("datamizacx.mdb")


set ks=server.createobject("adodb.recordset")
ks.open "select * from album_foto where katid = '5' and aktif=1 order by hit",bagg,1
%>

<?xml version="1.0" encoding="windows-1254" standalone="yes"?>
<images>

<%
do while not ks.eof
%>
	<pic>
		<image>kucukresim8.asp?r=<%=ks("dosyaadi")%></image>
		<caption><%=ks("baslik")%></caption>
	</pic>

<%
ks.movenext
loop
%>
</images>
