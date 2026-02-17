package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"

	admissionv1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	k8sruntime "k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/serializer"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"go.uber.org/zap"
)

var k8sDeserializer k8sruntime.Decoder

func init() {
	runtimeScheme := k8sruntime.NewScheme()
	_ = corev1.AddToScheme(runtimeScheme)
	k8sDeserializer = serializer.NewCodecFactory(runtimeScheme).UniversalDeserializer()
}

var log *zap.Logger

func init() {
	var err error
	log, err = zap.NewProduction()
	if err != nil {
		panic(fmt.Sprintf("failed to initialize logger: %v", err))
	}
}

var (
	Port              = 8443
	TLSCertFile       = "/etc/tls/tlcrt"
	TLSKeyFile        = "/etc/tls/tlkey"
	LonghornNamespace = "longhorn-system"
	PathPatch         = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/run/wrappers/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
)

func init() {
	flag.IntVar(&Port, "port", Port, "Port to listen on")
	flag.StringVar(&TLSCertFile, "tls-cert-file", TLSCertFile, "Path to TLS certificate")
	flag.StringVar(&TLSKeyFile, "tls-key-file", TLSKeyFile, "Path to TLS key")
	flag.StringVar(&LonghornNamespace, "longhorn-namespace", LonghornNamespace, "Name of longhorn namespace")
	flag.StringVar(&PathPatch, "path-patch", PathPatch, "Path variable to patch with")
}

func main() {
	defer log.Sync()
	flag.Parse()

	log.Info("starting admission controller",
		zap.Int("port", Port),
		zap.String("certFile", TLSCertFile),
		zap.String("keyFile", TLSKeyFile),
	)
	if err := app().StartTLS(fmt.Sprintf(":%d", Port), TLSCertFile, TLSKeyFile); err != nil {
		log.Fatal("server failed", zap.Error(err))
	}
}

func app() *echo.Echo {
	e := echo.New()
	e.HideBanner = true
	e.Use(middleware.Recover())

	e.GET("/health", func(c echo.Context) error {
		return c.JSON(http.StatusOK, map[string]string{"status": "healthy"})
	})

	g := e.Group("")
	g.Use(middleware.RequestLogger())
	g.POST("/validate", admitHandler(passthru))
	g.POST("/mutate", admitHandler(mutate))

	return e
}

func mutate(req *admissionv1.AdmissionRequest) (*admissionv1.AdmissionResponse, error) {
	log.Info("mutating resource",
		zap.String("kind", req.Kind.String()),
		zap.String("name", req.Name),
		zap.String("namespace", req.Namespace),
	)

	if req.Namespace != LonghornNamespace || req.Kind.Kind != "Pod" {
		return passthru(req)
	}

	var pod corev1.Pod
	if _, _, err := k8sDeserializer.Decode(req.Object.Raw, nil, &pod); err != nil {
		return nil, fmt.Errorf("failed to decode pod: %w", err)
	}

	var patches []map[string]any
	for jsonPath, containers := range map[string][]corev1.Container{
		"/spec/initContainers": pod.Spec.InitContainers,
		"/spec/containers":     pod.Spec.Containers,
	} {
		for i, c := range containers {
			// Container environment has no path var.
			patch := map[string]any{
				"op":    "add",
				"path":  fmt.Sprintf("%s/%d/env/-", jsonPath, i),
				"value": map[string]any{"name": "PATH", "value": PathPatch},
			}
			// Container has no environment.
			if len(c.Env) == 0 {
				patch = map[string]any{
					"op":    "add",
					"path":  fmt.Sprintf("%s/%d/env", jsonPath, i),
					"value": []map[string]any{{"name": "PATH", "value": PathPatch}},
				}
			}
			// Container environment has path var.
			for j, env := range c.Env {
				if env.Name != "PATH" {
					continue
				}
				patch = map[string]any{
					"op":    "replace",
					"path":  fmt.Sprintf("%s/%d/env/%d/value", jsonPath, i, j),
					"value": PathPatch,
				}
				break
			}
			patches = append(patches, patch)
		}
	}

	if len(patches) == 0 {
		return passthru(req)
	}

	patchBytes, err := json.Marshal(patches)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal patch: %w", err)
	}

	patchType := admissionv1.PatchTypeJSONPatch
	return &admissionv1.AdmissionResponse{
		Allowed:   true,
		Patch:     patchBytes,
		PatchType: &patchType,
	}, nil
}

func passthru(req *admissionv1.AdmissionRequest) (*admissionv1.AdmissionResponse, error) {
	return &admissionv1.AdmissionResponse{Allowed: true}, nil
}

type AdmitFunc func(*admissionv1.AdmissionRequest) (*admissionv1.AdmissionResponse, error)

func admitHandler(admitFunc AdmitFunc) echo.HandlerFunc {
	return func(c echo.Context) error {
		return handleAdmission(c, admitFunc)
	}
}

func handleAdmission(c echo.Context, admit AdmitFunc) error {
	body, err := io.ReadAll(c.Request().Body)
	if err != nil {
		log.Error("failed to read request body", zap.Error(err))
		return echo.NewHTTPError(http.StatusBadRequest, "could not read request body")
	}

	var admissionReview admissionv1.AdmissionReview
	if _, _, err := k8sDeserializer.Decode(body, nil, &admissionReview); err != nil {
		log.Error("failed to deserialize admission review", zap.Error(err))
		return echo.NewHTTPError(http.StatusBadRequest, "could not parse admission review")
	}

	if admissionReview.Request == nil {
		return echo.NewHTTPError(http.StatusBadRequest, "admission request is nil")
	}

	log.Info("processing admission request",
		zap.String("uid", string(admissionReview.Request.UID)),
		zap.String("kind", admissionReview.Request.Kind.String()),
		zap.String("operation", string(admissionReview.Request.Operation)),
	)

	response, err := admit(admissionReview.Request)
	if err != nil {
		log.Error("admission failed", zap.Error(err))
		response = &admissionv1.AdmissionResponse{
			UID:     admissionReview.Request.UID,
			Allowed: false,
			Result:  &metav1.Status{Message: err.Error()},
		}
	} else {
		response.UID = admissionReview.Request.UID
	}

	admissionResponse := admissionv1.AdmissionReview{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "admission.k8s.io/v1",
			Kind:       "AdmissionReview",
		},
		Response: response,
	}

	return c.JSON(http.StatusOK, admissionResponse)
}
