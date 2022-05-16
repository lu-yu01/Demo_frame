using UnityEngine;


public class GPUAnimPlayer : MonoBehaviour
{
    private Animator animator;
    private GPUAnimator gAnimator;

    [Range(0, 1)] public float fadeTime = 0.1f;

    public string ClipName1 = "idle";
    public string ClipName2 = "run";
    public string ClipName3 = "celebrate_1";
    public string ClipName4 = "celebrate_2";
    public string ClipName5 = "throw";
    public string ClipName6 = "attack";

    private void Awake()
    {
        gAnimator = GetComponentInChildren<GPUAnimator>();
        animator = GetComponentInChildren<Animator>();
    }
    // Start is called before the first frame update
    void Start()
    {
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.GetKeyUp(KeyCode.Alpha1)) { PlayClip(ClipName1, fadeTime); }
        else if (Input.GetKeyUp(KeyCode.Alpha2)) { PlayClip(ClipName2, fadeTime); }
        else if (Input.GetKeyUp(KeyCode.Alpha3)) { PlayClip(ClipName3, fadeTime); }
        else if (Input.GetKeyUp(KeyCode.Alpha4)) { PlayClip(ClipName4, fadeTime); }
        else if (Input.GetKeyUp(KeyCode.Alpha5)) { PlayClip(ClipName5, fadeTime); }
        else if (Input.GetKeyUp(KeyCode.Alpha6)) { PlayClip(ClipName6, fadeTime); }
    }

    private void OnDestroy()
    {
    }

    private void PlayClip(string clipOrStateName, float fadeTime)
    {
        if (gAnimator != null) gAnimator.Play(clipOrStateName, fadeTime);
        else animator.CrossFade(clipOrStateName, fadeTime);
    }
}