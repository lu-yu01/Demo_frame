using UnityEngine;

[ExecuteAlways]
public class GPUAnimUpdater
{
    public float CurSpeed;
    public bool IsPlaying { get { return mIsPlaying; } }
    public bool IsFading { get { return mFading; } }

    private bool mLoop = false;
    private bool mIsPlaying = false;
    private float mAnimLength;
    private float mCurTime = 0.0f;
    private float mNormalizedCurTime = 0.0f;

    private bool mFading = false;
    private float mWeight = 0.0f;
    private float mFadeTime = 0.0f;
    private bool mPreLoop = false;
    private float mPreAnimLength = 0.0f;
    private float mPreTime = 0.0f;
    private float mPreNormalizedTime = 0.0f;
    private System.Action mFadeCallback;


    public void Play(float curTime, float animLength, float speed, bool loop,float fadeTime = 0f)
    {
        if (animLength <= 0.0f)
        {
            throw new System.Exception("something is wrong, because anim length is 0.");
        }
        Fade(fadeTime);
        CurSpeed = speed;
        mCurTime = curTime;
        mAnimLength = animLength;
        mLoop = loop;
        mNormalizedCurTime = mCurTime / mAnimLength;
        mIsPlaying = true;
    }

    public void Fade(float fadeTime)
    {
        mWeight = 0;
        mFadeTime = fadeTime;
        mPreLoop = mLoop;
        mPreAnimLength = mAnimLength;
        mPreTime = mCurTime;
        mPreNormalizedTime = mNormalizedCurTime;
        mFading = fadeTime > 0 && mPreAnimLength > 0;
    }

    public void Stop()
    {
        mCurTime = mNormalizedCurTime = 0.0f;
        mLoop = false;
        mFading = false;
        mIsPlaying = false;
    }

    public void Pause()
    {
        mIsPlaying = false;
    }
    public void Resume()
    {
        mIsPlaying = true;
    }

    public void Update(float deltaTime)
    {
        if (!mIsPlaying)
        {
            return;
        }
        deltaTime *= CurSpeed;

        mCurTime += deltaTime;
        if (mLoop)
        {
            mCurTime = Mathf.Repeat(mCurTime, mAnimLength);
        }

        if (mCurTime > mAnimLength)
        {
            mCurTime = mAnimLength;
            mIsPlaying = false;
        }

        mNormalizedCurTime = mCurTime / mAnimLength;

        if (mFading)
        {
            if (mPreTime + deltaTime >= mPreAnimLength)
            {
                mPreTime = mPreLoop ? mPreTime + deltaTime - mPreAnimLength : mPreAnimLength;
            }
            else
            {
                mPreTime += deltaTime;
            }
            mPreNormalizedTime = mPreTime / mPreAnimLength;

            mWeight += deltaTime / mFadeTime;

            if (mWeight >= 1)
            {
                mWeight = 1;
                mFadeCallback?.Invoke();
                mFading = false;
            }
        }
        else {
            mWeight = 1;
        }
    }

    public void SetFadeCallback(System.Action cb)
    {
        mFadeCallback = cb;
    }
    public void SetCurTime(float time) 
    {
        mCurTime = time;
        mNormalizedCurTime = mCurTime / mAnimLength;
    }
    public float GetCurTime()
    {
        return mCurTime;
    }

    public void SetNormalizedCurTime(float nmlTime)
    {
        mNormalizedCurTime = nmlTime;
        mCurTime = mNormalizedCurTime * mAnimLength;
    }

    public float GetNormalizedCurTime()
    {
        return mNormalizedCurTime;
    }
    public float GetPreNormalizedTime()
    {
        return mPreNormalizedTime;
    }
    public float GetFadeWeight() 
    {
        return mWeight;
    }
   
}
