<% 
Set Tear_ac = CreateObject("SOFTWING.ASPtear" ) 

dim bilgicek 
bilgicek = Tear_ac.Retrieve("http://www22.brinkster.com/sdal/home/" , 2, "" , "" , "" ) 

On Error Resume Next 

%>
<%=bilgicek%><br><br><br>

