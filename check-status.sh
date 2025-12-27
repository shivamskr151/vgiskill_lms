#!/bin/bash
# Quick status check script

echo "=========================================="
echo "VariPhi LMS - Deployment Status"
echo "=========================================="
echo ""

echo "📦 Pods:"
kubectl get pods -l app.kubernetes.io/name=lms-app -o wide
echo ""

echo "🔌 Services:"
kubectl get svc -l app.kubernetes.io/name=lms-app
echo ""

echo "🌐 Ingress:"
kubectl get ingress -l app.kubernetes.io/name=lms-app
echo ""

echo "🔒 Managed Certificate:"
kubectl get managedcertificate variphi-lms-cert
echo ""

echo "=========================================="
echo "External IP for DNS Configuration"
echo "=========================================="
EXTERNAL_IP=$(kubectl get ingress -l app.kubernetes.io/name=lms-app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -z "$EXTERNAL_IP" ]; then
    echo "⏳ External IP is still being provisioned..."
    echo "   Run this script again in a few minutes"
else
    echo ""
    echo "✅ External IP: $EXTERNAL_IP"
    echo ""
    echo "Configure DNS:"
    echo "  Domain: vgiskill.ai"
    echo "  Type: A"
    echo "  Value: $EXTERNAL_IP"
    echo ""
fi

echo "=========================================="
echo "Pod Logs (last 10 lines)"
echo "=========================================="
kubectl logs -l app.kubernetes.io/name=lms-app --tail=10 2>&1 || echo "No logs available yet"

