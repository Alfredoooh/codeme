import { useState, useEffect } from "react";
import Home from "./Home";
import Editor from "./Editor";

export default function App() {
  const [screen, setScreen] = useState("home");
  const [activeDoc, setActiveDoc] = useState(null);
  const [docs, setDocs] = useState([
    { id:1, title:"Relatório Trimestral Q1", emoji:"1f4ca", preview:"Análise de desempenho Q1 com métricas e projeções para Q2.", date:"Hoje, 14:32", tag:"work", content:`<h1>Relatório Trimestral Q1</h1><p>Este relatório apresenta os resultados do primeiro trimestre.</p><h2>Resumo Executivo</h2><p>O trimestre foi marcado por crescimento consistente em todas as áreas.</p><h2>Métricas Principais</h2><p>• Receita: +12% vs Q4<br>• Clientes novos: 340<br>• Retenção: 94%</p><h2>Próximos Passos</h2><p>Foco em expansão do mercado e melhoria dos processos internos.</p>` },
    { id:2, title:"Notas de Reunião", emoji:"1f4dd", preview:"Roadmap do produto, sprint 12, feedback dos clientes.", date:"Hoje, 09:15", tag:"work", content:`<h1>Notas de Reunião — Equipa</h1><p><strong>Data:</strong> Hoje</p><h2>Pontos Discutidos</h2><p>1. Roadmap do produto para Q2<br>2. Prioridades do sprint 12<br>3. Feedback dos clientes</p><h2>Decisões</h2><p>• Avançar com feature X<br>• Rever UI do dashboard</p>` },
    { id:3, title:"Plano de Negócios", emoji:"1f3e2", preview:"Âmbito, objetivos e orçamento estimado.", date:"Ontem, 18:44", tag:"biz", content:`<h1>Plano de Negócios</h1><h2>Visão</h2><p>Criar a melhor plataforma de gestão documental.</p><h2>Mercado Alvo</h2><p>PMEs com 10–50 colaboradores.</p><h2>Modelo de Receita</h2><p>• Subscrição mensal: €15/utilizador<br>• Plano empresarial: €199/mês</p>` },
    { id:4, title:"Notas de Estudo", emoji:"1f393", preview:"Resumos, fórmulas e pontos-chave.", date:"Ontem, 11:20", tag:"school", content:`<h1>Notas de Estudo</h1><h2>Matemática</h2><p>Derivadas: f'(x) = lim(h→0) [f(x+h) - f(x)] / h</p><h2>Dicas de Estudo</h2><p>• Pomodoro: 25min estudo, 5min pausa<br>• Rever matéria no dia seguinte</p>` },
    { id:5, title:"Sermão — Domingo", emoji:"26ea", preview:"Texto base, pontos principais e ilustrações.", date:"2 Jan, 10:00", tag:"church", content:`<h1>Sermão — Domingo</h1><h2>Texto Base</h2><p>João 3:16</p><h2>Pontos Principais</h2><p>1. O amor incondicional<br>2. A fé como resposta<br>3. A vida em abundância</p>` },
  ]);
  const [projects, setProjects] = useState([
    { id:"p1", name:"School", emoji:"1f393", folders:[{id:"f1",name:"Matemática",emoji:"2795"},{id:"f2",name:"História",emoji:"1f4d6"}] },
    { id:"p2", name:"Church", emoji:"26ea", folders:[{id:"f3",name:"Sermões",emoji:"1f64f"}] },
    { id:"p3", name:"Business", emoji:"1f3e2", folders:[{id:"f4",name:"Finanças",emoji:"1f4b0"},{id:"f5",name:"Contratos",emoji:"1f4c4"}] },
  ]);

  const openEditor = (doc) => { setActiveDoc(doc); setScreen("editor"); };
  const goHome = () => setScreen("home");

  return (
    <div style={{position:"relative",width:"100%",height:"100%",overflow:"hidden",background:"#f2f2f7"}}>
      <Home
        visible={screen==="home"}
        docs={docs} setDocs={setDocs}
        projects={projects} setProjects={setProjects}
        onOpenEditor={openEditor}
      />
      <Editor
        visible={screen==="editor"}
        doc={activeDoc}
        onBack={goHome}
      />
    </div>
  );
}