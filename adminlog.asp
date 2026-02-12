<%response.buffer=true%>
<%sayfaadi="Yönetim Hata ve IP Kayýtlarý"%>
<%sayfaurl="adminlog.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> | 
<hr color=brown size=1>
<a href="adminlog.asp" title="Hata ve IP Kayýtlarý">Hata ve IP Kayýtlarý</a><br>
<table border=0 cellpadding=3 cellspacing=1 width=800>
<tr><td style="background:white;border:1 solid #663300;" align=left>
<%
klasor = "hatalog"
Set FSO = CreateObject("Scripting.FileSystemObject")
yol = FSO.BuildPath(Request.servervariables("APPL_PHYSICAL_PATH"),klasor)

if request.querystring("dg") = "e" then
da = request.querystring("da")
yol = FSO.BuildPath(yol,da)
If FSO.FileExists(yol) = True Then

if left(da,5) = "sayac" or left(da,5) = "uyeip" then
start=4
else
start=12
end if
Set Dosya = FSO.OpenTextFile(yol)
i=1
k=0
Do While Not Dosya.AtEndOfStream

    Satir = Dosya.ReadLine
if Dosya.Line > start then
if k=1 then
Response.Write Satir & "<hr color=#ededed size=1>"
i=i+1
k=0
else
Response.Write "<b>"& i & "</b> - " & Satir & "<hr color=#ededed size=1>"
k=1
end if
else
    Response.Write Satir & "<br>"
end if

    If Dosya.AtEndOfStream = True Then
       Response.Write "Dosya Bitti. Toplam <b>"&i-1&"</b>."
    End If

Loop

Dosya.Close

else
response.write "Dosya Bulunamadý!"
end if
else

Set mKlasor = FSO.GetFolder(yol)
Set dosyalar = mKlasor.Files
response.write "<b>Bu ayýn kayýtlarý</b>"
For Each Dosya in dosyalar
	if Dosya.Name = Month(Date()) & Year(Date()) & ".txt" or Dosya.Name = "sayac" & Month(Date()) & Year(Date()) & ".txt" or Dosya.Name = "uyeip" & Month(Date()) & Year(Date()) & ".txt"then
     Response.Write "<li><a href=adminlog.asp?dg=e&da="&Dosya.Name&">"&Dosya.Name&"</a>"
	end if
Next

response.write "<hr size=1><b>Geçen aylarýn kayýtlarý</b>"
For Each Dosya in dosyalar
	if Dosya.Name <> Month(Date()) & Year(Date()) & ".txt" and Dosya.Name <> "sayac" & Month(Date()) & Year(Date()) & ".txt" and Dosya.Name <> "uyeip" & Month(Date()) & Year(Date()) & ".txt"then
     Response.Write "<li><a href=adminlog.asp?dg=e&da="&Dosya.Name&">"&Dosya.Name&"</a>"
	end if
Next

end if
%>
</td></tr></table>
<br><a href="adminlog.asp" title="Hata ve IP Kayýtlarý">Hata ve IP Kayýtlarý</a>
<br>

  <%else%>
<!--#include file="admingiris.asp"-->
<%end if%>
<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->