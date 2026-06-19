import { createClient } from "@supabase/supabase-js"

const EXPO_PUSH_URL = "https://exp.host/--/api/v2/push/send"

Deno.serve(async (req) => {
    try {
        // 1. Validar cabeçalho de autenticação (x-webhook-secret)
        const webhookSecret = Deno.env.get("WEBHOOK_SECRET")
        const receivedSecret = req.headers.get("x-webhook-secret")

        if (webhookSecret && receivedSecret !== webhookSecret) {
            return new Response(JSON.stringify({ error: "Unauthorized" }), {
                status: 401,
                headers: { "Content-Type": "application/json" },
            })
        }

        // 2. Extrair o payload enviado pelo Webhook
        const payload = await req.json()
        console.log("Payload recebido:", JSON.stringify(payload))

        const { record, type: opType } = payload

        // Garantir que é uma operação de inserção
        if (opType !== "INSERT" || !record) {
            return new Response(JSON.stringify({ message: "Ignore non-insert operations" }), {
                status: 200,
                headers: { "Content-Type": "application/json" },
            })
        }

        const { id: notificationId, type: notifType, description, id_senior, id_caretaker, id_volunteer } = record

        // 3. Determinar o ID do destinatário
        const targetUserId = id_caretaker || id_senior || id_volunteer

        if (!targetUserId) {
            return new Response(JSON.stringify({ message: "No target user specified" }), {
                status: 200,
                headers: { "Content-Type": "application/json" },
            })
        }

        // 4. Inicializar cliente do Supabase com a chave Service Role (ignora RLS)
        const supabaseUrl = Deno.env.get("SUPABASE_URL")!
        const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
        const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

        // 5. Procurar o push_token na tabela users
        const { data: user, error: userError } = await supabase
            .from("users")
            .select("push_token")
            .eq("id", targetUserId)
            .single()

        if (userError || !user) {
            console.error(`Erro ao obter utilizador ${targetUserId}:`, userError)
            return new Response(JSON.stringify({ error: "Recipient user not found" }), {
                status: 404,
                headers: { "Content-Type": "application/json" },
            })
        }

        const pushToken = user.push_token

        if (!pushToken) {
            console.log(`Utilizador ${targetUserId} não tem push_token registado.`)
            return new Response(JSON.stringify({ message: "User has no push token" }), {
                status: 200,
                headers: { "Content-Type": "application/json" },
            })
        }

        // 6. Definir título baseado no tipo de notificação
        let title = "🔔 Geras"
        if (notifType === "medication") {
            title = "💊 Lembrete de Medicação"
        } else if (notifType === "alert") {
            title = "🚨 Alerta de Segurança"
        } else if (notifType === "request") {
            title = "🔔 Novo Pedido de Ajuda"
        }

        // 7. Disparar notificação para os servidores da Expo
        const expoResponse = await fetch(EXPO_PUSH_URL, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
            body: JSON.stringify({
                to: pushToken,
                sound: "default",
                title: title,
                body: description,
                data: {
                    notificationId,
                    type: notifType,
                },
            }),
        })

        const expoResult = await expoResponse.json()
        console.log("Resposta do Expo:", JSON.stringify(expoResult))

        return new Response(JSON.stringify({ success: true, result: expoResult }), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        })
    } catch (error) {
        console.error("Erro na Edge Function:", error)
        const errorMessage = error instanceof Error ? error.message : String(error)
        return new Response(JSON.stringify({ error: errorMessage }), {
            status: 500,
            headers: { "Content-Type": "application/json" },
        })
    }
})
